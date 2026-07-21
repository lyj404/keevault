import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/core/utils/fuzzy_match.dart';

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
}
