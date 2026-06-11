import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../settings/data/webdav_config.dart';

class RemoteFileInfo {
  final String? eTag;
  final DateTime? mTime;
  const RemoteFileInfo({this.eTag, this.mTime});
}

class SyncService {
  webdav.Client _buildClient(WebDavConfig config, {bool debug = false}) {
    final client = webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: config.password,
      debug: debug,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(15000);
    client.setReceiveTimeout(30000);
    return client;
  }

  /// Tests WebDAV connection. Returns null on success, error key on failure.
  /// Error keys: 'auth_failed', 'path_not_accessible', 'connection_failed', 'network_failed'
  Future<String?> testConnection(WebDavConfig config) async {
    try {
      final client = _buildClient(config, debug: true);
      final remotePath = config.remotePath.isEmpty ? '/' : config.remotePath;
      try {
        await client.readDir(remotePath);
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('401') || msg.contains('403')) {
          return 'auth_failed';
        }
        if (msg.contains('404') || msg.contains('409')) {
          return null;
        }
        try {
          await client.ping();
          return 'path_not_accessible:$remotePath';
        } catch (_) {
          return 'connection_failed:$msg';
        }
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('403')) {
        return 'auth_failed';
      }
      if (msg.contains('SocketException') || msg.contains('Connection')) {
        return 'network_failed';
      }
      return 'connection_failed:$msg';
    }
  }

  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    final client = _buildClient(config);
    await client.mkdirAll(config.remotePath);
  }

  Future<Uint8List?> downloadDatabase(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      final bytes = await client.read(config.remoteFilePath);
      return Uint8List.fromList(bytes);
    } catch (_) {
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
  Future<({Uint8List bytes, RemoteFileInfo info})?> downloadWithInfo(WebDavConfig config) async {
    final client = _buildClient(config);
    try {
      final bytes = await client.read(config.remoteFilePath);
      final file = await client.readProps(config.remoteFilePath);
      return (bytes: Uint8List.fromList(bytes), info: RemoteFileInfo(eTag: file.eTag, mTime: file.mTime));
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadDatabase(WebDavConfig config, Uint8List bytes) async {
    final client = _buildClient(config);
    await client.write(config.remoteFilePath, bytes);
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
