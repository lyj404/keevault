import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../../settings/data/webdav_config.dart';

class SyncService {
  webdav.Client _buildClient(WebDavConfig config) {
    final client = webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: config.password,
    );
    client.setConnectTimeout(15000);
    client.setSendTimeout(15000);
    client.setReceiveTimeout(30000);
    return client;
  }

  Future<bool> testConnection(WebDavConfig config) async {
    try {
      final client = _buildClient(config);
      await client.ping();
      return true;
    } catch (_) {
      return false;
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
    if (bytes == null) throw Exception('远程数据库不存在');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/keevault_sync.kdbx');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
