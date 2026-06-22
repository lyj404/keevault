import 'dart:io';
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

class SyncService {
  webdav.Client? _cachedClient;
  WebDavConfig? _cachedConfig;

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
      final bytes = await client.read(config.remoteFilePath);
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
      final file = await client.readProps(config.remoteFilePath);
      return RemoteFileInfo(eTag: file.eTag, mTime: file.mTime);
    } catch (_) {
      return null;
    }
  }

  /// Downloads database bytes along with remote file metadata.
  /// Reads props FIRST to capture the eTag, then downloads. This avoids the
  /// TOCTOU race where the file could change between download and eTag fetch.
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(WebDavConfig config) async {
    log.i('Downloading with metadata from: ${config.remoteFilePath}');
    final client = _buildClient(config);
    try {
      // Read props first to capture the eTag of the current version
      final file = await client.readProps(config.remoteFilePath);
      final bytes = await client.read(config.remoteFilePath);
      log.i('Downloaded ${bytes.length} bytes, eTag: ${file.eTag}');
      return (bytes: Uint8List.fromList(bytes), info: RemoteFileInfo(eTag: file.eTag, mTime: file.mTime));
    } catch (e) {
      log.e('Download with info failed', error: e);
      return null;
    }
  }

  /// Uploads database to WebDAV using an atomic temp-file-then-rename pattern.
  /// This prevents a partially written file from corrupting the remote database
  /// if the connection drops mid-transfer.
  Future<void> uploadDatabase(WebDavConfig config, Uint8List bytes) async {
    log.i('Uploading ${bytes.length} bytes to: ${config.remoteFilePath}');
    final client = _buildClient(config);
    final tmpPath = '${config.remoteFilePath}.tmp';
    try {
      // Write to a temporary file first
      await client.write(tmpPath, bytes);
      // Atomic rename to final path (WebDAV MOVE is atomic on compliant servers)
      try {
        await client.rename(tmpPath, config.remoteFilePath, true);
      } catch (_) {
        // If MOVE is not supported, fall back to direct write
        log.w('MOVE not supported, falling back to direct write');
        await client.write(config.remoteFilePath, bytes);
        try { await client.remove(tmpPath); } catch (_) {}
      }
    } catch (e) {
      // Clean up temp file on failure
      try { await client.remove(tmpPath); } catch (_) {}
      rethrow;
    }
    log.i('Upload complete');
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
