import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/features/database/data/atomic_file_store.dart';

void main() {
  group('AtomicFileStore', () {
    late Directory directory;
    late String target;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('keevault_atomic_');
      target = '${directory.path}${Platform.pathSeparator}vault.kdbx';
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('commits new bytes and removes transaction artifacts', () async {
      await File(target).writeAsBytes([1, 2, 3], flush: true);
      var backupCalled = false;

      final result = await const AtomicFileStore().commit(
        target,
        Uint8List.fromList([4, 5, 6]),
        backup: () async => backupCalled = true,
      );

      expect(await File(target).readAsBytes(), [4, 5, 6]);
      expect(result.bytesWritten, 3);
      expect(backupCalled, isTrue);
      expect(await File('$target.keevault.transaction.json').exists(), isFalse);
    });

    test('keeps the original when backup fails', () async {
      await File(target).writeAsBytes([1, 2, 3], flush: true);

      await expectLater(
        const AtomicFileStore().commit(
          target,
          Uint8List.fromList([9, 9, 9]),
          backup: () async => throw StateError('backup failed'),
        ),
        throwsStateError,
      );

      expect(await File(target).readAsBytes(), [1, 2, 3]);
      expect(await File('$target.keevault.transaction.json').exists(), isTrue);
      expect(await const AtomicFileStore().candidates(target), isNotEmpty);
    });
  });
}
