import 'package:flutter/material.dart';

/// Claymorphism design system for KeeVault.
/// Soft, rounded shapes with inner/outer shadows creating a clay-like 3D feel.
class ClayColors {
  // Primary palette – teal green
  static const primary = Color(0xFF0D9488);
  static const primaryLight = Color(0xFF2DD4BF);
  static const primaryDark = Color(0xFF0F766E);

  // Secondary – emerald accent
  static const secondary = Color(0xFF10B981);
  static const secondaryLight = Color(0xFF34D399);

  // Tertiary – amber warm accent
  static const tertiary = Color(0xFFF59E0B);
  static const tertiaryLight = Color(0xFFFBBF24);

  // Surfaces – warm cream tones
  static const surfaceLight = Color(0xFFF5F9F8);
  static const surfaceCardLight = Color(0xFFFFFFFF);
  static const surfaceContainerLight = Color(0xFFECF5F3);

  // Dark surfaces
  static const surfaceDark = Color(0xFF111918);
  static const surfaceCardDark = Color(0xFF1A2625);
  static const surfaceContainerDark = Color(0xFF22302E);

  // Text
  static const onSurfaceLight = Color(0xFF1A2B29);
  static const onSurfaceVariantLight = Color(0xFF5F7370);
  static const outlineLight = Color(0xFF8FA5A2);

  static const onSurfaceDark = Color(0xFFE0F0ED);
  static const onSurfaceVariantDark = Color(0xFFA3B8B5);
  static const outlineDark = Color(0xFF6B807D);

  // Error
  static const error = Color(0xFFEF5350);
  static const errorLight = Color(0xFFFFCDD2);
  static const errorDark = Color(0xFFD32F2F);
}

/// Pre-built clay box decorations for reuse across the app.
class ClayDecoration {
  /// Outer shadow for the raised clay effect.
  static List<BoxShadow> outerShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFF8AB8B3).withValues(alpha: 0.3),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: const Color(0xFF8AB8B3).withValues(alpha: 0.12),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Inner glow for the pressed/inset clay effect.
  static List<BoxShadow> innerShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: const Color(0xFFB8D8D3).withValues(alpha: 0.4),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Full clay container decoration (outer glow + background + radius).
  static BoxDecoration card({
    required Brightness brightness,
    Color? color,
    double radius = 20,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: outerShadow(brightness),
    );
  }

  /// Input field clay decoration.
  static BoxDecoration input({
    required Brightness brightness,
    bool focused = false,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? ClayColors.surfaceContainerDark : ClayColors.surfaceContainerLight,
      borderRadius: BorderRadius.circular(16),
      boxShadow: innerShadow(brightness),
      border: focused
          ? Border.all(color: ClayColors.primary, width: 2)
          : Border.all(
              color: (isDark ? ClayColors.outlineDark : ClayColors.outlineLight).withValues(alpha: 0.3),
              width: 1,
            ),
    );
  }

  /// Icon container with clay feel.
  static BoxDecoration iconContainer({
    required Brightness brightness,
    Color? color,
    double radius = 14,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? (isDark
          ? ClayColors.primary.withValues(alpha: 0.2)
          : ClayColors.primary.withValues(alpha: 0.12)),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: (color ?? ClayColors.primary).withValues(alpha: isDark ? 0.15 : 0.1),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class AppTheme {
  // Cross-platform CJK font fallback
  static const _fontFallback = <String>[
    'Microsoft YaHei',    // Windows
    'PingFang SC',        // macOS
    'Noto Sans CJK SC',   // Linux
    'sans-serif',
  ];

  static TextStyle _withFallback(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(fontFamilyFallback: _fontFallback);
  }

  static TextTheme _applyFallback(TextTheme theme) {
    return theme.copyWith(
      displayLarge: _withFallback(theme.displayLarge),
      displayMedium: _withFallback(theme.displayMedium),
      displaySmall: _withFallback(theme.displaySmall),
      headlineLarge: _withFallback(theme.headlineLarge),
      headlineMedium: _withFallback(theme.headlineMedium),
      headlineSmall: _withFallback(theme.headlineSmall),
      titleLarge: _withFallback(theme.titleLarge),
      titleMedium: _withFallback(theme.titleMedium),
      titleSmall: _withFallback(theme.titleSmall),
      bodyLarge: _withFallback(theme.bodyLarge),
      bodyMedium: _withFallback(theme.bodyMedium),
      bodySmall: _withFallback(theme.bodySmall),
      labelLarge: _withFallback(theme.labelLarge),
      labelMedium: _withFallback(theme.labelMedium),
      labelSmall: _withFallback(theme.labelSmall),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: ClayColors.primary,
        onPrimary: Colors.white,
        primaryContainer: ClayColors.primaryLight.withValues(alpha: 0.2),
        onPrimaryContainer: ClayColors.primaryDark,
        secondary: ClayColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: ClayColors.secondaryLight.withValues(alpha: 0.2),
        onSecondaryContainer: const Color(0xFF1A5C3A),
        tertiary: ClayColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: ClayColors.tertiaryLight.withValues(alpha: 0.2),
        onTertiaryContainer: const Color(0xFF1A5C57),
        error: ClayColors.error,
        onError: Colors.white,
        errorContainer: ClayColors.errorLight,
        onErrorContainer: ClayColors.errorDark,
        surface: ClayColors.surfaceLight,
        onSurface: ClayColors.onSurfaceLight,
        onSurfaceVariant: ClayColors.onSurfaceVariantLight,
        outline: ClayColors.outlineLight,
        outlineVariant: ClayColors.outlineLight.withValues(alpha: 0.3),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: ClayColors.surfaceContainerLight,
        surfaceContainer: const Color(0xFFE0EFEC),
        surfaceContainerHigh: const Color(0xFFD4E8E4),
        surfaceContainerHighest: const Color(0xFFC8E0DC),
      ),
      scaffoldBackgroundColor: ClayColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: ClayColors.surfaceLight,
        foregroundColor: ClayColors.onSurfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceLight,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClayColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClayColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: ClayColors.surfaceContainerLight,
        labelStyle: TextStyle(color: ClayColors.onSurfaceVariantLight, fontSize: 14),
        hintStyle: TextStyle(color: ClayColors.outlineLight, fontSize: 14),
        prefixIconColor: ClayColors.onSurfaceVariantLight,
        suffixIconColor: ClayColors.onSurfaceVariantLight,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: ClayColors.outlineLight.withValues(alpha: 0.15),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClayColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          side: BorderSide.none,
          backgroundColor: ClayColors.surfaceContainerLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        backgroundColor: ClayColors.onSurfaceLight,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ClayColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceLight,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        color: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClayColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: ClayColors.outlineLight.withValues(alpha: 0.4)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ClayColors.primary,
        inactiveTrackColor: ClayColors.primary.withValues(alpha: 0.15),
        thumbColor: ClayColors.primary,
        overlayColor: ClayColors.primary.withValues(alpha: 0.1),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      textTheme: _applyFallback(ThemeData.light().textTheme),
      primaryTextTheme: _applyFallback(ThemeData.light().primaryTextTheme),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: ClayColors.primaryLight,
        onPrimary: const Color(0xFF1A1030),
        primaryContainer: ClayColors.primary.withValues(alpha: 0.25),
        onPrimaryContainer: ClayColors.primaryLight,
        secondary: ClayColors.secondaryLight,
        onSecondary: const Color(0xFF2D1515),
        secondaryContainer: ClayColors.secondary.withValues(alpha: 0.25),
        onSecondaryContainer: ClayColors.secondaryLight,
        tertiary: ClayColors.tertiaryLight,
        onTertiary: const Color(0xFF0D2D2A),
        tertiaryContainer: ClayColors.tertiary.withValues(alpha: 0.25),
        onTertiaryContainer: ClayColors.tertiaryLight,
        error: const Color(0xFFEF9A9A),
        onError: const Color(0xFF2D1010),
        errorContainer: const Color(0xFF4A1515),
        onErrorContainer: const Color(0xFFEF9A9A),
        surface: ClayColors.surfaceDark,
        onSurface: ClayColors.onSurfaceDark,
        onSurfaceVariant: ClayColors.onSurfaceVariantDark,
        outline: ClayColors.outlineDark,
        outlineVariant: ClayColors.outlineDark.withValues(alpha: 0.3),
        surfaceContainerLowest: const Color(0xFF0D1514),
        surfaceContainerLow: ClayColors.surfaceContainerDark,
        surfaceContainer: const Color(0xFF2A3B38),
        surfaceContainerHigh: const Color(0xFF334542),
        surfaceContainerHighest: const Color(0xFF3C4F4C),
      ),
      scaffoldBackgroundColor: ClayColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: ClayColors.surfaceDark,
        foregroundColor: ClayColors.onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceDark,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ClayColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF9A9A), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: ClayColors.surfaceContainerDark,
        labelStyle: TextStyle(color: ClayColors.onSurfaceVariantDark, fontSize: 14),
        hintStyle: TextStyle(color: ClayColors.outlineDark, fontSize: 14),
        prefixIconColor: ClayColors.onSurfaceVariantDark,
        suffixIconColor: ClayColors.onSurfaceVariantDark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: ClayColors.outlineDark.withValues(alpha: 0.15),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ClayColors.primaryLight,
          foregroundColor: const Color(0xFF1A1030),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.primaryLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          side: BorderSide.none,
          backgroundColor: ClayColors.surfaceContainerDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        backgroundColor: ClayColors.surfaceContainerDark,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ClayColors.primaryLight,
        foregroundColor: const Color(0xFF1A1030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: ClayColors.surfaceCardDark,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceDark,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        color: ClayColors.surfaceCardDark,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClayColors.primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: ClayColors.outlineDark.withValues(alpha: 0.4)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ClayColors.primaryLight,
        inactiveTrackColor: ClayColors.primaryLight.withValues(alpha: 0.15),
        thumbColor: ClayColors.primaryLight,
        overlayColor: ClayColors.primaryLight.withValues(alpha: 0.1),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      textTheme: _applyFallback(ThemeData.dark().textTheme),
      primaryTextTheme: _applyFallback(ThemeData.dark().primaryTextTheme),
    );
  }
}
