import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keevault/core/theme/app_theme.dart';

void main() {
  group('AppTheme.resolveFontFamily', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('Windows zh uses Microsoft YaHei UI', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.resolveFontFamily(const Locale('zh')),
        'Microsoft YaHei UI',
      );
    });

    test('Windows en uses Segoe UI Variable Display', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.resolveFontFamily(const Locale('en')),
        'Segoe UI Variable Display',
      );
    });

    test('Linux zh uses Noto Sans CJK SC', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        AppTheme.resolveFontFamily(const Locale('zh')),
        'Noto Sans CJK SC',
      );
    });

    test('Linux en uses Noto Sans', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(AppTheme.resolveFontFamily(const Locale('en')), 'Noto Sans');
    });

    test('Android does not force a font family', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppTheme.resolveFontFamily(const Locale('zh')), isNull);
      expect(AppTheme.resolveFontFamily(const Locale('en')), isNull);
    });
  });

  group('AppTheme typography', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('shared type scale is consistent', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.light(locale: const Locale('en'));
      final tt = theme.textTheme;

      expect(tt.titleMedium?.fontSize, 15);
      expect(tt.titleMedium?.fontWeight, FontWeight.w700);
      expect(tt.bodyMedium?.fontSize, 14);
      expect(tt.bodySmall?.fontSize, 12);
      expect(tt.labelSmall?.fontSize, 11);
    });

    test('light theme snackbar keeps readable white body text', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final style = AppTheme.light(
        locale: const Locale('en'),
      ).snackBarTheme.contentTextStyle;

      expect(style, isNotNull);
      expect(style!.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, Colors.white);
    });

    test('dark theme uses high-contrast text on elevated surface', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.dark(locale: const Locale('en'));
      final style = theme.snackBarTheme.contentTextStyle;

      expect(style, isNotNull);
      expect(style!.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, ClayColors.onSurfaceDark);
      expect(theme.snackBarTheme.backgroundColor, isNot(ClayColors.surfaceDark));
    });

    test('dark theme has solid containers and readable onPrimary', () {
      final scheme = AppTheme.dark(locale: const Locale('en')).colorScheme;
      expect(scheme.primaryContainer.a, greaterThan(0.99));
      expect(scheme.onSurface, ClayColors.onSurfaceDark);
      expect(scheme.onSurfaceVariant, ClayColors.onSurfaceVariantDark);
      expect(scheme.onPrimary, ClayColors.onPrimaryDark);
    });

    test('text styles inherit platform + locale font', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.light(locale: const Locale('zh')).textTheme.bodyMedium?.fontFamily,
        'Microsoft YaHei UI',
      );
      expect(
        AppTheme.light(locale: const Locale('en')).textTheme.bodyMedium?.fontFamily,
        'Segoe UI Variable Display',
      );
      expect(
        AppTheme.light(locale: const Locale('zh')).textTheme.titleMedium?.fontFamily,
        'Microsoft YaHei UI',
      );
    });

    test('list tiles share titleMedium / bodySmall', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.light(locale: const Locale('en'));
      expect(theme.listTileTheme.titleTextStyle?.fontSize, 15);
      expect(theme.listTileTheme.titleTextStyle?.fontWeight, FontWeight.w700);
      expect(theme.listTileTheme.subtitleTextStyle?.fontSize, 12);
    });
  });
}
