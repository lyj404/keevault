import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'webdav_config.dart';

class WebDavSettingsService {
  static const _configKey = 'webdav_config';
  final _storage = const SecureStorageHelper();

  Future<WebDavConfig?> getConfig() async {
    final json = await _storage.read(key: _configKey);
    if (json == null) return null;
    return WebDavConfig.decode(json);
  }

  Future<void> saveConfig(WebDavConfig config) async {
    await _storage.write(key: _configKey, value: config.encode());
  }

  Future<void> deleteConfig() async {
    await _storage.delete(key: _configKey);
    // Clean up cached cloud database file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/keevault_cloud_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        log.i('Cloud cache directory deleted');
      }
    } catch (e) {
      log.e('Failed to clean cloud cache', error: e);
    }
  }
}
