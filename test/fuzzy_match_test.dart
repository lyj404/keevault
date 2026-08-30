import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/core/utils/fuzzy_match.dart';

KdbxEntry _makeEntry() {
  final dir = Directory.systemTemp.createTempSync('fuzzy_');
  addTearDown(() => dir.delete(recursive: true));
  final db = KdbxDatabase.create(
    credentials: KdbxCredentials(
      password: ProtectedData.fromString('pw'),
    ),
    name: 't',
  );
  final entry = db.createEntry(parent: db.root);
  return entry;
}

void main() {
  group('fuzzyMatch', () {
    test('prefers a prefix over an embedded substring', () {
      final prefix = fuzzyMatch('github account', 'git');
      final embedded = fuzzyMatch('my github account', 'git');

      expect(prefix, isNotNull);
      expect(embedded, isNotNull);
      expect(prefix!.score, greaterThan(embedded!.score));
      expect(prefix.positions, [0, 1, 2]);
    });

    test('matches case-insensitively', () {
      final result = fuzzyMatch('GitHub', 'github');

      expect(result, isNotNull);
      expect(result!.positions, [0, 1, 2, 3, 4, 5]);
    });

    test('tracks non-consecutive fuzzy match positions', () {
      final result = fuzzyMatch('Google Account', 'gac');

      expect(result, isNotNull);
      expect(result!.positions, [0, 7, 8]);
    });

    test('rejects a query whose characters are out of order', () {
      expect(fuzzyMatch('github', 'bti'), isNull);
    });

    test('treats an empty query as a match', () {
      final result = fuzzyMatch('anything', '');

      expect(result, isNotNull);
      expect(result!.score, 1.0);
      expect(result.positions, isEmpty);
    });
  });

  group('entryFields', () {
    test('exposes searchable fields and excludes the Password field', () {
      final entry = _makeEntry();
      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitHub');
      entry.fields['UserName'] = KdbxTextField.fromText(text: 'alice');
      entry.fields['Password'] = KdbxTextField.fromText(text: 'secret');
      entry.tags = ['work', 'dev'];

      final fields = entryFields(entry);
      final names = fields.map((f) => f.$2).toSet();
      expect(names.contains('Title'), true);
      expect(names.contains('UserName'), true);
      expect(names.contains('Password'), false);
      expect(fields.any((f) => f.$1 == 'work'), true);
    });
  });

  group('fuzzyMatchEntry', () {
    test('matches across multiple fields and returns a positive score', () {
      final entry = _makeEntry();
      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitLab');
      entry.fields['URL'] = KdbxTextField.fromText(text: 'https://gitlab.com');

      final match = fuzzyMatchEntry(entry, 'gitlab');
      expect(match, isNotNull);
      expect(match!.isMatch, true);
    });

    test('returns null-ish/empty for a query that matches nothing', () {
      final entry = _makeEntry();
      entry.fields['Title'] = KdbxTextField.fromText(text: 'GitHub');

      final match = fuzzyMatchEntry(entry, 'zzz');
      expect(match, isNull);
    });
  });
}

