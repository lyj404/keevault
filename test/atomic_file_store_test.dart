import 'dart:convert';
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

    Future<List<String>> artifactNames() async =>
        (await directory.list().toList())
            .where((e) => e is File && e.path.contains('.keevault.'))
            .map((e) => e.path)
            .toList();

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
      expect(await const AtomicFileStore().readPending(target), isNull);
      expect(await artifactNames(), isEmpty);
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
      expect(await const AtomicFileStore().readPending(target), isNotNull);
      expect(await const AtomicFileStore().candidates(target), isNotEmpty);
    });

    test('discovers the pending manifest written by an older version',
        () async {
      await File(target).writeAsBytes([1, 2, 3], flush: true);
      // Legacy fixed-name manifest (pre-token layout).
      await File('$target.keevault.transaction.json').writeAsString(
        jsonEncode({
          'target': target,
          'temp': '$target.t',
          'rollback': '$target.r',
          'sha256': 'abc',
          'length': 3,
          'stage': 'writing',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        flush: true,
      );

      expect(await const AtomicFileStore().readPending(target), isNotNull);
      await const AtomicFileStore().discardPending(target);
      expect(await const AtomicFileStore().readPending(target), isNull);
    });

    test('discards stale temp/rollback files left after recovery', () async {
      await File(target).writeAsBytes([1, 2, 3], flush: true);
      await const AtomicFileStore().commit(
        target,
        Uint8List.fromList([7, 8, 9]),
      );
      expect(await const AtomicFileStore().readPending(target), isNull);
      expect(await artifactNames(), isEmpty);
    });
  });
}
