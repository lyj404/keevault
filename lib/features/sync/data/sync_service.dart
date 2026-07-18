import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../../core/utils/fnv_hash.dart';
import '../../../core/utils/logger.dart';
import '../../settings/data/webdav_config.dart';

class RemoteFileInfo {
  final String? eTag;
  final DateTime? mTime;
  const RemoteFileInfo({this.eTag, this.mTime});
}

/// Classification of sync errors for user-friendly messaging.
enum SyncErrorType {
  network,
  auth,
  notFound,
  timeout,
  conflict,
  serverError,
  unknown,
}

class SyncException implements Exception {
  final SyncErrorType type;
  final String message;
  final Object? original;
  SyncException(this.type, this.message, [this.original]);

  @override
  String toString() => 'SyncException($type): $message';
}

class SyncService {
  webdav.Client? _cachedClient;
  WebDavConfig? _cachedConfig;
  static const _maxRetries = 3;
  static const _baseDelayMs = 1000;

  /// Classifies transport failures using typed Dio metadata whenever it is
  /// available. String matching is retained only for third-party WebDAV
  /// exceptions that do not expose a status code.
  SyncErrorType _classifyError(Object error) {
    if (error is SyncException) return error.type;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return SyncErrorType.auth;
      if (status == 404) return SyncErrorType.notFound;
      if (status == 409 || status == 412) return SyncErrorType.conflict;
      if (status != null && status >= 500) return SyncErrorType.serverError;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return SyncErrorType.timeout;
      }
      if (error.type == DioExceptionType.connectionError) {
        return SyncErrorType.network;
      }
    }
    if (error is SocketException) return SyncErrorType.network;
    final message = error.toString().toLowerCase();
    if (message.contains('401') || message.contains('403')) {
      return SyncErrorType.auth;
    }
    if (message.contains('404')) return SyncErrorType.notFound;
    if (message.contains('409') || message.contains('412')) {
      return SyncErrorType.conflict;
    }
    if (message.contains('timeout')) return SyncErrorType.timeout;
    return SyncErrorType.unknown;
  }

  /// Whether an error is transient and worth retrying.
  bool _isRetryable(SyncErrorType type) {
    return type == SyncErrorType.network ||
        type == SyncErrorType.timeout ||
        type == SyncErrorType.serverError;
  }

  /// Wraps an async operation with exponential backoff retry for transient errors.
  Future<T> _withRetry<T>(String operation, Future<T> Function() action) async {
    Object? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        final type = _classifyError(e);
        if (!_isRetryable(type) || attempt == _maxRetries - 1) {
          log.e(
            '$operation failed (attempt ${attempt + 1}/$_maxRetries)',
            error: e,
          );
          if (type != SyncErrorType.unknown) {
            throw SyncException(type, e.toString(), e);
          }
          rethrow;
        }
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        log.w(
          '$operation failed, retrying in ${delay}ms (attempt ${attempt + 1}/$_maxRetries): $e',
        );
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
    throw lastError!;
  }

  /// Returns a cached WebDAV client, rebuilding it only when config changes.
  webdav.Client _buildClient(WebDavConfig config, {bool debug = false}) {
    if (!debug && _cachedClient != null && _cachedConfig == config) {
      return _cachedClient!;
    }
    final client = webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: config.password,
      debug: debug,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(15000);
    client.setReceiveTimeout(30000);
    if (!debug) {
      _cachedClient = client;
      _cachedConfig = config;
    }
    return client;
  }

  /// Clears cached WebDAV client and config to remove sensitive data from memory.
  void clearCache() {
    _cachedClient = null;
    _cachedConfig = null;
  }

  /// Tests WebDAV connection. Returns null on success, error key on failure.
  /// Error keys: 'auth_failed', 'path_not_accessible', 'connection_failed', 'network_failed'
  Future<String?> testConnection(WebDavConfig config) async {
    log.i('Testing WebDAV connection: ${config.serverUrl}');
    try {
      final client = _buildClient(config);
      final remotePath = config.remotePath.isEmpty ? '/' : config.remotePath;
      try {
        await client.readDir(remotePath);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('401') || msg.contains('403')) {
          log.w('Auth failed');
          return 'auth_failed';
        }
        if (msg.contains('404') || msg.contains('409')) {
          return null;
        }
        try {
          await client.ping();
          log.w('Path not accessible: $remotePath');
          return 'path_not_accessible:$remotePath';
        } catch (_) {
          log.e('Connection failed', error: msg);
          return 'connection_failed:$msg';
        }
      }
      log.i('Connection test passed');
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('403')) {
        log.w('Auth failed');
        return 'auth_failed';
      }
      if (msg.contains('SocketException') || msg.contains('Connection')) {
        log.e('Network failed');
        return 'network_failed';
      }
      log.e('Connection failed', error: msg);
      return 'connection_failed:$msg';
    }
  }

  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    final client = _buildClient(config);
    await client.mkdirAll(config.remotePath);
  }

  Future<Uint8List?> downloadDatabase(WebDavConfig config) async {
    log.i('Downloading from: ${config.remoteFilePath}');
    final client = _buildClient(config);
    try {
      final bytes = await _withRetry(
        'Download',
        () => client.read(config.remoteFilePath),
      );
      log.i('Downloaded ${bytes.length} bytes');
      return Uint8List.fromList(bytes);
    } catch (e) {
      log.e('Download failed', error: e);
      return null;
    }
  }

  Future<RemoteFileInfo?> getRemoteFileInfo(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      final file = await _withRetry(
        'GetFileInfo',
        () => client.readProps(config.remoteFilePath),
      );
      return RemoteFileInfo(eTag: file.eTag, mTime: file.mTime);
    } catch (_) {
      return null;
    }
  }

  /// Downloads bytes and revision metadata from the same HTTP GET response,
  /// avoiding a read/readProps race where the reported ETag could belong to a
  /// newer version than the downloaded bytes.
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(
    WebDavConfig config,
  ) async {
    log.i('Downloading database with revision metadata');
    final client = _buildClient(config);
    try {
      final response = await _withRetry(
        'Download',
        () => client.c.req<List<int>>(
          client,
          'GET',
          config.remoteFilePath,
          optionsHandler: (options) =>
              options.responseType = ResponseType.bytes,
        ),
      );
      final status = response.statusCode;
      if (status != 200) throw _httpException(status, response.statusMessage);
      final data = response.data;
      if (data == null) {
        throw SyncException(SyncErrorType.serverError, 'Empty WebDAV response');
      }
      final info = RemoteFileInfo(
        eTag: response.headers.value('etag'),
        mTime: _parseHttpDate(response.headers.value('last-modified')),
      );
      log.i('Downloaded ${data.length} bytes with a revision token');
      return (bytes: Uint8List.fromList(data), info: info);
    } catch (error) {
      final typed = _asSyncException(error);
      log.e('Download with info failed', error: typed);
      if (typed.type == SyncErrorType.notFound) return null;
      throw typed;
    }
  }

  /// Atomically uploads only if the remote revision still matches
  /// [expected]. New files use If-None-Match so an unexpectedly created file
  /// cannot be overwritten. Conditional PUT is deliberately never retried:
  /// after an ambiguous network failure the caller must fetch remote state.
  Future<RemoteFileInfo> uploadDatabase(
    WebDavConfig config,
    Uint8List bytes, {
    RemoteFileInfo? expected,
    bool force = false,
  }) async {
    log.i('Uploading ${bytes.length} bytes with conflict protection');
    final client = _buildClient(config);
    try {
      final response = await client.c.req<void>(
        client,
        'PUT',
        config.remoteFilePath,
        data: Stream<List<int>>.value(bytes),
        optionsHandler: (options) {
          options.headers?['content-length'] = bytes.length;
          if (!force) {
            final eTag = expected?.eTag;
            options.headers?[eTag == null ? 'if-none-match' : 'if-match'] =
                eTag ?? '*';
          }
        },
      );
      final status = response.statusCode;
      if (status != 200 && status != 201 && status != 204) {
        throw _httpException(status, response.statusMessage);
      }
      log.i('Upload complete');
      final responseETag = response.headers.value('etag');
      final responseMTime = _parseHttpDate(
        response.headers.value('last-modified'),
      );
      if (responseETag != null || responseMTime != null) {
        return RemoteFileInfo(eTag: responseETag, mTime: responseMTime);
      }
      return await getRemoteFileInfo(config) ?? const RemoteFileInfo();
    } catch (error) {
      final typed = _asSyncException(error);
      log.e('Upload failed', error: typed);
      throw typed;
    }
  }

  SyncException _httpException(int? status, String? message) {
    final type = switch (status) {
      401 || 403 => SyncErrorType.auth,
      404 => SyncErrorType.notFound,
      409 || 412 => SyncErrorType.conflict,
      int value when value >= 500 => SyncErrorType.serverError,
      _ => SyncErrorType.unknown,
    };
    return SyncException(
      type,
      'WebDAV HTTP ${status ?? 'unknown'}: ${message ?? ''}',
    );
  }

  SyncException _asSyncException(Object error) => error is SyncException
      ? error
      : SyncException(_classifyError(error), 'WebDAV operation failed', error);

  DateTime? _parseHttpDate(String? value) {
    if (value == null) return null;
    try {
      return HttpDate.parse(value);
    } catch (_) {
      return null;
    }
  }

  Future<bool> remoteFileExists(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      await client.readProps(config.remoteFilePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads remote database and writes it to the local cloud cache.
  /// Returns path + revision metadata from the same GET response so callers
  /// never persist a stale ETag against newer bytes.
  Future<({String path, RemoteFileInfo info})> downloadToLocal(
    WebDavConfig config,
  ) async {
    final result = await downloadWithInfo(config);
    if (result == null) throw Exception('remote_database_not_exist');
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/keevault_cloud_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final file = File('${cacheDir.path}/${_cacheFileNameFor(config)}');
    await file.writeAsBytes(result.bytes, flush: true);
    return (path: file.path, info: result.info);
  }

  String _cacheFileNameFor(WebDavConfig config) {
    final extension = _normalizedExtension(config.remoteFilename);
    final identity =
        '${config.serverUrl.trim()}|${config.remoteFilePath.trim()}';
    final hash = _stableHash(identity);
    final safeName = _sanitizeFileStem(config.remoteFilename);
    return '${safeName}_$hash$extension';
  }

  String _sanitizeFileStem(String filename) {
    final normalized = filename.trim();
    final dotIndex = normalized.lastIndexOf('.');
    final stem = dotIndex > 0 ? normalized.substring(0, dotIndex) : normalized;
    final cleaned = stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'keevault_sync' : cleaned;
  }

  String _normalizedExtension(String filename) {
    final normalized = filename.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == normalized.length - 1) {
      return '.kdbx';
    }
    final extension = normalized.substring(dotIndex);
    final cleaned = extension.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
    return cleaned.isEmpty ? '.kdbx' : cleaned;
  }

  String _stableHash(String input) => FnvHash.hashString(input);
}
