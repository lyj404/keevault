import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/sync/data/sync_service.dart';

void main() {
  group('encodeDavPath', () {
    test('collapses duplicate slashes and strips a trailing slash', () {
      expect(encodeDavPath('//a//b//'), '/a/b');
      expect(encodeDavPath('a/b/'), 'a/b');
    });

    test('keeps the root and the empty path as-is', () {
      expect(encodeDavPath('/'), '/');
      expect(encodeDavPath('   '), '');
    });

    test('percent-encodes characters that break request URLs', () {
      expect(encodeDavPath('/my docs/db#1.kdbx'), '/my%20docs/db%231.kdbx');
      expect(encodeDavPath('/a?b.kdbx'), '/a%3Fb.kdbx');
      expect(
        encodeDavPath('/KeePass/密码库.kdbx'),
        '/KeePass/%E5%AF%86%E7%A0%81%E5%BA%93.kdbx',
      );
    });

    test('leaves existing percent-escapes and reserved characters alone', () {
      expect(encodeDavPath('/a%20b/c@d,e~f'), '/a%20b/c@d,e~f');
    });
  });

  group('normalizeETag', () {
    test('strips the weak-validator prefix and whitespace', () {
      expect(normalizeETag('W/"abc123"'), '"abc123"');
      expect(normalizeETag('w/"abc123"'), '"abc123"');
      expect(normalizeETag('  "abc123"  '), '"abc123"');
    });

    test('keeps strong etags untouched', () {
      expect(normalizeETag('"abc123"'), '"abc123"');
      expect(normalizeETag('abc123'), 'abc123');
    });

    test('maps empty values to null', () {
      expect(normalizeETag(null), isNull);
      expect(normalizeETag(''), isNull);
      expect(normalizeETag('   '), isNull);
      expect(normalizeETag('W/'), isNull);
    });
  });

  group('buildConditionalUploadHeaders', () {
    test('a never-seen remote uses If-None-Match: *', () {
      expect(
        buildConditionalUploadHeaders(null),
        {'if-none-match': '*'},
      );
    });

    test('a known ETag uses If-Match with the normalized value', () {
      expect(
        buildConditionalUploadHeaders(
          const RemoteFileInfo(eTag: 'W/"abc"'),
        ),
        {'if-match': '"abc"'},
      );
    });

    test('a validator-less server falls back to If-Unmodified-Since', () {
      final mTime = DateTime.utc(2026, 1, 2, 3, 4, 5);
      expect(
        buildConditionalUploadHeaders(RemoteFileInfo(mTime: mTime)),
        {'if-unmodified-since': HttpDate.format(mTime)},
      );
    });

    test('a seen revision without any validator is a conflict, not an '
        'unconditional upload', () {
      expect(
        () => buildConditionalUploadHeaders(const RemoteFileInfo()),
        throwsA(
          isA<SyncException>().having(
            (e) => e.type,
            'type',
            SyncErrorType.conflict,
          ),
        ),
      );
    });
  });
}
