import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/features/backup/data/backup_service.dart';

void main() {
  group('BackupService integrity verification', () {
    late Directory directory;
    late BackupService service;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('keevault_backup_');
      service = BackupService(backupDirectory: directory);
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Future<void> writeBackup(
      String filename,
      List<int> bytes, {
      Object? metadata,
    }) async {
      await File(
        '${directory.path}${Platform.pathSeparator}$filename',
      ).writeAsBytes(bytes);
      if (metadata != null) {
        await File(
          '${directory.path}${Platform.pathSeparator}$filename.meta.json',
        ).writeAsString(jsonEncode(metadata));
      }
    }

    test('accepts a backup with matching size and SHA-256', () async {
      const filename = 'valid.kdbx';
      final bytes = <int>[1, 2, 3, 4];
      final digest = await Sha256().hash(bytes);
      final hash = digest.bytes
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      await writeBackup(
        filename,
        bytes,
        metadata: {'sizeBytes': bytes.length, 'sha256': hash},
      );

      final result = await service.verifyAndReadBackup(filename);

      expect(result.status, BackupIntegrityStatus.valid);
      expect(result.bytes, bytes);
      expect(result.canRestore, isTrue);
    });

    test('rejects a size mismatch', () async {
      await writeBackup(
        'size.kdbx',
        [1, 2],
        metadata: {'sizeBytes': 3, 'sha256': '0' * 64},
      );

      final result = await service.verifyAndReadBackup('size.kdbx');

      expect(result.status, BackupIntegrityStatus.corrupted);
      expect(result.canRestore, isFalse);
    });

    test('rejects a SHA-256 mismatch', () async {
      await writeBackup(
        'hash.kdbx',
        [1, 2],
        metadata: {'sizeBytes': 2, 'sha256': '0' * 64},
      );

      final result = await service.verifyAndReadBackup('hash.kdbx');

      expect(result.status, BackupIntegrityStatus.corrupted);
    });

    test('accepts legacy backup without metadata', () async {
      await writeBackup('legacy.kdbx', [9, 8, 7]);

      final result = await service.verifyAndReadBackup('legacy.kdbx');

      expect(result.status, BackupIntegrityStatus.legacy);
      expect(result.bytes, [9, 8, 7]);
      expect(result.canRestore, isTrue);
    });

    test('rejects malformed metadata', () async {
      const filename = 'invalid.kdbx';
      await writeBackup(filename, [1]);
      await File(
        '${directory.path}${Platform.pathSeparator}$filename.meta.json',
      ).writeAsString('{not-json');

      final result = await service.verifyAndReadBackup(filename);

      expect(result.status, BackupIntegrityStatus.invalid);
      expect(result.canRestore, isFalse);
    });

    test('reports a missing backup', () async {
      final result = await service.verifyAndReadBackup('missing.kdbx');

      expect(result.status, BackupIntegrityStatus.missing);
      expect(result.bytes, isNull);
    });
  });
}
