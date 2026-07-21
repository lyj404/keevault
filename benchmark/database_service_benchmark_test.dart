import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keevault/features/database/data/database_service.dart';

/// Run explicitly with:
/// flutter test benchmark/database_service_benchmark_test.dart
///
/// This benchmark is intentionally outside test/ so it does not slow CI.
void main() {
  test('DatabaseService 5000-entry baseline', () async {
    final directory = await Directory.systemTemp.createTemp(
      'keevault_database_benchmark_',
    );
    final path = '${directory.path}${Platform.pathSeparator}benchmark.kdbx';
    final service = DatabaseService();

    try {
      await service.createDatabase('Benchmark', 'benchmark-password', path);
      final root = service.db!.root;
      for (var i = 0; i < 5000; i++) {
        final entry = service.createEntry(root);
        final suffix = i.toString().padLeft(5, '0');
        entry.fields['Title'] = KdbxTextField.fromText(
          text: 'Example account $suffix',
        );
        entry.fields['UserName'] = KdbxTextField.fromText(
          text: 'user$suffix@example.com',
        );
        entry.fields['URL'] = KdbxTextField.fromText(
          text: 'https://example.com/$suffix',
        );
        entry.fields['Notes'] = KdbxTextField.fromText(
          text: 'Benchmark note for account $suffix',
        );
        entry.tags = ['benchmark', 'batch-${i % 20}'];
      }
      service.rebuildEntryCache();

      final indexAndSearch = Stopwatch()..start();
      final firstResults = service.search('example account 04999');
      indexAndSearch.stop();

      final warmSearch = Stopwatch()..start();
      final warmResults = service.search('user@example.com');
      warmSearch.stop();

      final serialization = Stopwatch()..start();
      final bytes = await service.saveToBytes();
      serialization.stop();

      stdout.writeln(
        'entries=5000 bytes=${bytes.length} '
        'index+search=${indexAndSearch.elapsedMilliseconds}ms '
        'warm-search=${warmSearch.elapsedMilliseconds}ms '
        'serialize=${serialization.elapsedMilliseconds}ms '
        'first-results=${firstResults.length} '
        'warm-results=${warmResults.length}',
      );
      expect(firstResults, isNotEmpty);
      expect(warmResults, isNotEmpty);
    } finally {
      service.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
