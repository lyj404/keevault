import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
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

  /// Classifies an exception into a [SyncErrorType] for user-friendly messaging.
  SyncErrorType _classifyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('401') || msg.contains('403') || msg.contains('unauthorized')) {
      return SyncErrorType.auth;
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return SyncErrorType.notFound;
    }
    if (msg.contains('socketexception') || msg.contains('connection refused') ||
        msg.contains('network') || msg.contains('host') ||
        msg.contains('connection reset') || msg.contains('broken pipe')) {
      return SyncErrorType.network;
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return SyncErrorType.timeout;
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503') || msg.contains('504')) {
      return SyncErrorType.serverError;
    }
    return SyncErrorType.unknown;
  }

  /// Whether an error is transient and worth retrying.
  bool _isRetryable(SyncErrorType type) {
    return type == SyncErrorType.network ||
           type == SyncErrorType.timeout ||
           type == SyncErrorType.serverError;
  }

  /// Wraps an async operation with exponential backoff retry for transient errors.
  Future<T> _withRetry<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    Object? lastError;
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        final type = _classifyError(e);
        if (!_isRetryable(type) || attempt == _maxRetries - 1) {
          log.e('$operation failed (attempt ${attempt + 1}/$_maxRetries)', error: e);
          if (type != SyncErrorType.unknown) {
            throw SyncException(type, e.toString(), e);
          }
          rethrow;
        }
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        log.w('$operation failed, retrying in ${delay}ms (attempt ${attempt + 1}/$_maxRetries): $e');
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
      final client = _buildClient(config, debug: true);
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
      final bytes = await _withRetry('Download', () => client.read(config.remoteFilePath));
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
      final file = await _withRetry('GetFileInfo', () => client.readProps(config.remoteFilePath));
      return RemoteFileInfo(eTag: file.eTag, mTime: file.mTime);
    } catch (_) {
      return null;
    }
  }

  /// Downloads database bytes along with remote file metadata.
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(WebDavConfig config) async {
    log.i('Downloading with metadata from: ${config.remoteFilePath}');
    final client = _buildClient(config);
    try {
      final bytes = await _withRetry('Download', () => client.read(config.remoteFilePath));
      // Read props after download to get the eTag of the version we actually received.
      final file = await client.readProps(config.remoteFilePath);
      log.i('Downloaded ${bytes.length} bytes, eTag: ${file.eTag}');
      return (bytes: Uint8List.fromList(bytes), info: RemoteFileInfo(eTag: file.eTag, mTime: file.mTime));
    } catch (e) {
      log.e('Download with info failed', error: e);
      return null;
    }
  }

  Future<void> uploadDatabase(WebDavConfig config, Uint8List bytes) async {
    log.i('Uploading ${bytes.length} bytes to: ${config.remoteFilePath}');
    final client = _buildClient(config);
    try {
      await _withRetry('Upload', () => client.write(config.remoteFilePath, bytes));
      log.i('Upload complete');
    } catch (e) {
      log.e('Upload failed', error: e);
      rethrow;
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

  Future<String> downloadToLocal(WebDavConfig config) async {
    final bytes = await downloadDatabase(config);
    if (bytes == null) throw Exception('remote_database_not_exist');
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/keevault_cloud_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final file = File('${cacheDir.path}/keevault_sync.kdbx');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
