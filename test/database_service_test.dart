import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keevault/features/database/data/database_service.dart';

void main() {
  group('DatabaseService lifecycle and search', () {
    late Directory directory;
    late String databasePath;
    late DatabaseService service;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('keevault_database_');
      databasePath = '${directory.path}${Platform.pathSeparator}vault.kdbx';
      service = DatabaseService();
    });

    tearDown(() async {
      if (service.isOpen) service.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('creates, indexes, searches, and closes a database', () async {
      await service.createDatabase('Test vault', 'test-password', databasePath);
      final root = service.db!.root;
      final entry = service.createEntry(root);
      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitHub');
      entry.fields['UserName'] = KdbxTextField.fromText(
        text: 'alice@example.com',
      );
      service.rebuildEntryCache();

      final results = service.search('git');
      expect(results, hasLength(1));
      expect(results.single.entry, same(entry));

      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitLab');
      service.rebuildEntryCache();
      expect(service.search('github'), isEmpty);
      expect(service.search('gitlab'), hasLength(1));

      service.close();
      expect(service.isOpen, isFalse);
      expect(service.allEntries, isEmpty);
    });

    test(
      'persists entries and reopens them with the master password',
      () async {
        await service.createDatabase(
          'Test vault',
          'test-password',
          databasePath,
        );
        final entry = service.createEntry(service.db!.root);
        entry.fields['Title'] = KdbxTextField.fromText(text: 'Saved account');
        entry.fields['URL'] = KdbxTextField.fromText(
          text: 'https://example.com',
        );
        service.rebuildEntryCache();

        final bytes = await service.saveToBytes();
        await File(databasePath).writeAsBytes(bytes, flush: true);
        service.close();
        await service.openFile(databasePath, 'test-password');

        final results = service.search('example.com');
        expect(results, hasLength(1));
        expect(results.single.entry.fields['Title']?.text, 'Saved account');
        expect(service.isDirty, isFalse);
      },
    );

    test(
      'invalidates the old master password after a password change',
      () async {
        await service.createDatabase(
          'Test vault',
          'old-password',
          databasePath,
        );
        service.changePassword('old-password', 'new-password');
        final bytes = await service.saveToBytes();
        await File(databasePath).writeAsBytes(bytes, flush: true);
        service.close();

        await expectLater(
          service.openFile(databasePath, 'old-password'),
          throwsA(isA<InvalidCredentialsError>()),
        );
        expect(service.isOpen, isFalse);

        await service.openFile(databasePath, 'new-password');
        expect(service.isOpen, isTrue);
        expect(service.isDirty, isFalse);
      },
    );
  });
}
