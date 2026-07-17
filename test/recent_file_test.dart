import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/features/database/data/recent_files_service.dart';

void main() {
  group('RecentFile pending upload compatibility', () {
    test('old JSON defaults pendingUpload to false', () {
      final file = RecentFile.fromJson({'path': 'vault.kdbx'});

      expect(file.pendingUpload, isFalse);
    });

    test('pendingUpload round-trips when true', () {
      const original = RecentFile(
        path: 'vault.kdbx',
        isCloud: true,
        pendingUpload: true,
      );

      final restored = RecentFile.fromJson(original.toJson());

      expect(restored.pendingUpload, isTrue);
      expect(restored.isCloud, isTrue);
    });

    test('false pendingUpload is omitted from persisted JSON', () {
      const file = RecentFile(path: 'vault.kdbx');

      expect(file.toJson().containsKey('pendingUpload'), isFalse);
    });
  });
}
