import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/core/theme/app_theme.dart';

void main() {
  group('AppTheme SnackBar typography', () {
    for (final theme in <ThemeData>[AppTheme.light(), AppTheme.dark()]) {
      test('${theme.brightness.name} theme uses the bundled regular font', () {
        final style = theme.snackBarTheme.contentTextStyle;

        expect(style, isNotNull);
        expect(style!.fontFamily, 'Noto Sans SC');
        expect(style.fontFamilyFallback, const <String>[
          'Microsoft YaHei',
          'PingFang SC',
          'Noto Sans CJK SC',
          'sans-serif',
        ]);
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.color, Colors.white);
      });
    }
  });
}
