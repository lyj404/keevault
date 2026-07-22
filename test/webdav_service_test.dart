import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/features/settings/data/webdav_config.dart';
import 'package:keevault/features/settings/data/webdav_service.dart';

void main() {
  test('migrates a legacy WebDAV config without recursive loading', () async {
    FlutterSecureStorage.setMockInitialValues({
      'webdav_config': jsonEncode({
        'serverUrl': 'https://example.com/dav',
        'username': 'user',
        'password': 'test-password',
        'remotePath': '/vaults',
        'remoteFilename': 'vault.kdbx',
        'enabled': true,
      }),
    });

    final state = await WebDavSettingsService().getProfilesState().timeout(
      const Duration(seconds: 1),
    );

    expect(state.profiles, hasLength(1));
    expect(state.activeProfileId, 'webdav_legacy');
    expect(state.activeProfile?.password, 'test-password');

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'webdav_config'), isNull);
    final migratedJson = await storage.read(key: 'webdav_profiles');
    expect(migratedJson, isNotNull);
    final migrated = WebDavProfilesState.decode(migratedJson!);
    expect(migrated.profiles, hasLength(1));
    expect(migrated.profiles.single.password, startsWith('ENC2:'));
  });
}
