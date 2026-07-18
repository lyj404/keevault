import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/core/theme/app_theme.dart';

void main() {
  group('AppTheme SnackBar typography', () {
    test('light theme uses the bundled regular font', () {
      final style = AppTheme.light().snackBarTheme.contentTextStyle;

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

    test('dark theme uses high-contrast text on elevated surface', () {
      final theme = AppTheme.dark();
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
      expect(style.color, ClayColors.onSurfaceDark);
      expect(theme.snackBarTheme.backgroundColor, isNot(ClayColors.surfaceDark));
    });

    test('dark theme has solid containers and readable onPrimary', () {
      final scheme = AppTheme.dark().colorScheme;
      expect(scheme.primaryContainer.a, greaterThan(0.99));
      expect(scheme.onSurface, ClayColors.onSurfaceDark);
      expect(scheme.onSurfaceVariant, ClayColors.onSurfaceVariantDark);
      // Filled controls use dark ink on light primary accents in ColorScheme;
      // FilledButton theme overrides to white on brand teal.
      expect(scheme.onPrimary, ClayColors.onPrimaryDark);
    });
  });
}
