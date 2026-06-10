import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'webdav_config.dart';

class WebDavSettingsService {
  static const _configKey = 'webdav_config';
  final _storage = const FlutterSecureStorage();

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
  }
}
