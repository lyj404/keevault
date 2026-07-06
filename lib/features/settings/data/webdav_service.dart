import '../../../core/utils/secure_storage_helper.dart';
import 'webdav_config.dart';

class WebDavSettingsService {
  static const _configKey = 'webdav_profiles';
  static const _legacyConfigKey = 'webdav_config';
  final _storage = const SecureStorageHelper();

  Future<WebDavConfig?> getConfig() async {
    return (await getProfilesState()).activeProfile;
  }

  Future<WebDavConfig?> getConfigById(String? profileId) async {
    final state = await getProfilesState();
    if (profileId == null) return state.activeProfile;
    for (final profile in state.profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  Future<WebDavProfilesState> getProfilesState() async {
    final json = await _storage.read(key: _configKey);
    if (json != null) {
      return WebDavProfilesState.decode(json);
    }

    final legacyJson = await _storage.read(key: _legacyConfigKey);
    if (legacyJson == null) {
      return const WebDavProfilesState(profiles: [], activeProfileId: null);
    }

    final legacyConfig = WebDavConfig.decode(
      legacyJson,
    ).copyWith(id: 'webdav_legacy', name: 'Default');
    final migrated = WebDavProfilesState(
      profiles: [legacyConfig],
      activeProfileId: legacyConfig.id,
    );
    await _storage.write(key: _configKey, value: migrated.encode());
    await _storage.delete(key: _legacyConfigKey);
    return migrated;
  }

  Future<void> saveConfig(WebDavConfig config) async {
    final state = await getProfilesState();
    final profiles = [...state.profiles];
    final index = profiles.indexWhere((profile) => profile.id == config.id);
    if (index >= 0) {
      profiles[index] = config;
    } else {
      profiles.add(config);
    }
    final updated = WebDavProfilesState(
      profiles: profiles,
      activeProfileId: config.id,
    );
    await _storage.write(key: _configKey, value: updated.encode());
  }

  Future<void> deleteConfig() async {
    await _storage.delete(key: _legacyConfigKey);
    await _storage.delete(key: _configKey);
  }

  Future<void> deleteProfile(String profileId) async {
    final state = await getProfilesState();
    final profiles = state.profiles
        .where((profile) => profile.id != profileId)
        .toList();
    final nextActive = state.activeProfileId == profileId
        ? (profiles.isEmpty ? null : profiles.first.id)
        : state.activeProfileId;
    final updated = WebDavProfilesState(
      profiles: profiles,
      activeProfileId: nextActive,
    );
    await _storage.write(key: _configKey, value: updated.encode());
  }

  Future<void> setActiveProfile(String profileId) async {
    final state = await getProfilesState();
    final exists = state.profiles.any((profile) => profile.id == profileId);
    if (!exists) return;
    final updated = WebDavProfilesState(
      profiles: state.profiles,
      activeProfileId: profileId,
    );
    await _storage.write(key: _configKey, value: updated.encode());
  }
}
