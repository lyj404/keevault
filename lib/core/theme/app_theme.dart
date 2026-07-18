import 'package:flutter/material.dart';

/// Layout tokens (spacing, radius, density). Colors stay in [ClayColors].
class ClayLayout {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  /// Wide / desktop explorer layout breakpoint.
  static const double wideBreakpoint = 700;

  /// Comfortable max width for single-column content on large screens.
  static const double contentMaxWidth = 1120;

  static const double sidebarWidth = 280;
  static const double touchMin = 48;
  static const double iconButton = 36;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static bool isDesktopPlatform(BuildContext context) {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.linux ||
        p == TargetPlatform.macOS;
  }
}

/// Claymorphism design system for KeeVault.
/// Soft, rounded shapes with inner/outer shadows creating a clay-like 3D feel.
/// Color scheme: Teal Green (matching logo)
class ClayColors {
  // Primary palette – teal green
  static const primary = Color(0xFF0D9488);
  static const primaryLight = Color(0xFF2DD4BF);
  static const primaryDark = Color(0xFF0F766E);
  static const primaryMuted = Color(0xFF5EEAD4);

  // Secondary – emerald accent
  static const secondary = Color(0xFF10B981);
  static const secondaryLight = Color(0xFF34D399);
  static const secondaryMuted = Color(0xFF6EE7B7);

  // Tertiary – amber warm accent
  static const tertiary = Color(0xFFF59E0B);
  static const tertiaryLight = Color(0xFFFBBF24);

  // Surfaces – warm cream tones (light)
  static const surfaceLight = Color(0xFFF5F9F8);
  static const surfaceCardLight = Color(0xFFFFFFFF);
  static const surfaceContainerLight = Color(0xFFECF5F3);

  // Dark surfaces – clearer elevation steps (bg < container < card)
  static const surfaceDark = Color(0xFF0C1413);
  static const surfaceCardDark = Color(0xFF1C2E2B);
  static const surfaceContainerDark = Color(0xFF152422);

  // Text (light mode)
  static const onSurfaceLight = Color(0xFF1A2B29);
  static const onSurfaceVariantLight = Color(0xFF5F7370);
  static const outlineLight = Color(0xFF8FA5A2);

  // Text (dark mode) – higher contrast on dark teal surfaces
  static const onSurfaceDark = Color(0xFFF0FAF8);
  static const onSurfaceVariantDark = Color(0xFFB7CBC7);
  static const outlineDark = Color(0xFF7F9692);

  // Dark interactive fills (avoid light primary + white text)
  static const onPrimaryDark = Color(0xFF042F2E);
  static const primaryContainerDark = Color(0xFF134E4A);
  static const onPrimaryContainerDark = Color(0xFF99F6E4);
  static const secondaryContainerDark = Color(0xFF065F46);
  static const onSecondaryContainerDark = Color(0xFFA7F3D0);

  // Error
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const errorDark = Color(0xFFDC2626);
  static const errorOnDark = Color(0xFFFCA5A5);
  static const errorContainerDark = Color(0xFF5C1A1A);
  static const onErrorContainerDark = Color(0xFFFECACA);
}

/// Pre-built clay box decorations for reuse across the app.
class ClayDecoration {
  // Cached decorations to avoid per-build allocations.
  static final _cardCache = <(Brightness, double), BoxDecoration>{};
  static final _iconContainerCache = <(Brightness, double), BoxDecoration>{};

  /// Outer shadow for the raised clay effect (softer, less color bloom).
  static List<BoxShadow> outerShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: const Color(0xFF5EEAD4).withValues(alpha: 0.12),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// Subtle list-row elevation (one layer only).
  static List<BoxShadow> listShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Sidebar edge shadow (wide layout).
  static List<BoxShadow> sidebarShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(2, 0),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(2, 0),
      ),
    ];
  }

  /// Inner glow for the pressed/inset clay effect.
  static List<BoxShadow> innerShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF6EE7B7).withValues(alpha: 0.18),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Full clay container decoration (outer glow + background + radius).
  static BoxDecoration card({
    required Brightness brightness,
    Color? color,
    double radius = ClayLayout.radiusXl,
  }) {
    if (color != null) {
      return BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: outerShadow(brightness),
      );
    }
    final key = (brightness, radius);
    return _cardCache[key] ??= BoxDecoration(
      color: brightness == Brightness.dark
          ? ClayColors.surfaceCardDark
          : ClayColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: outerShadow(brightness),
    );
  }

  /// Lightweight list-row surface (less shadow stacking in long lists).
  static BoxDecoration listItem({
    required Brightness brightness,
    required ColorScheme colorScheme,
    bool selected = false,
    double radius = ClayLayout.radiusLg,
  }) {
    final isDark = brightness == Brightness.dark;
    if (selected) {
      // Cannot combine non-uniform Border with borderRadius; use solid fill only.
      return BoxDecoration(
        color: isDark
            ? ClayColors.primaryContainerDark
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.55 : 0.35),
        ),
        boxShadow: listShadow(brightness),
      );
    }
    return BoxDecoration(
      color: isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colorScheme.outline.withValues(alpha: isDark ? 0.28 : 0.22),
      ),
      boxShadow: listShadow(brightness),
    );
  }

  /// Input field clay decoration.
  static BoxDecoration input({
    required Brightness brightness,
    bool focused = false,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? ClayColors.surfaceContainerDark
          : ClayColors.surfaceContainerLight,
      borderRadius: BorderRadius.circular(16),
      boxShadow: innerShadow(brightness),
      border: focused
          ? Border.all(color: ClayColors.primary, width: 2)
          : Border.all(
              color: (isDark ? ClayColors.outlineDark : ClayColors.outlineLight)
                  .withValues(alpha: 0.3),
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
    if (color != null) {
      final isDark = brightness == Brightness.dark;
      return BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }
    final key = (brightness, radius);
    return _iconContainerCache[key] ??= _buildIconContainer(brightness, radius);
  }

  static BoxDecoration _buildIconContainer(
    Brightness brightness,
    double radius,
  ) {
    final isDark = brightness == Brightness.dark;
    final bgColor = isDark
        ? ClayColors.primaryContainerDark
        : ClayColors.primary.withValues(alpha: 0.12);
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class AppTheme {
  // Cached theme instances — built once, reused on every rebuild.
  static ThemeData? _light;
  static ThemeData? _dark;

  // Cross-platform CJK font fallback
  static const _fontFallback = <String>[
    'Microsoft YaHei', // Windows
    'PingFang SC', // macOS
    'Noto Sans CJK SC', // Linux
    'sans-serif',
  ];

  static TextStyle _withFallback(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: _fontFallback,
    );
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

  static ThemeData light() => _light ??= _buildLight();
  static ThemeData dark() => _dark ??= _buildDark();

  static ThemeData _buildLight() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Noto Sans SC',
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
        onSecondaryContainer: const Color(0xFF065F46),
        tertiary: ClayColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: ClayColors.tertiaryLight.withValues(alpha: 0.2),
        onTertiaryContainer: const Color(0xFF92400E),
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
        surfaceContainer: const Color(0xFFD5E8E4),
        surfaceContainerHigh: const Color(0xFFC8DFD9),
        surfaceContainerHighest: const Color(0xFFB8D4CC),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        filled: true,
        fillColor: ClayColors.surfaceContainerLight,
        labelStyle: TextStyle(
          color: ClayColors.onSurfaceVariantLight,
          fontSize: 14,
        ),
        hintStyle: TextStyle(color: ClayColors.outlineLight, fontSize: 14),
        prefixIconColor: ClayColors.onSurfaceVariantLight,
        suffixIconColor: ClayColors.onSurfaceVariantLight,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
        ),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusMd),
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.onSurfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ClayColors.onSurfaceLight,
          ),
          side: BorderSide.none,
          backgroundColor: ClayColors.surfaceContainerLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        backgroundColor: ClayColors.onSurfaceLight,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ClayColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceLight,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: ClayColors.onSurfaceLight,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        elevation: 4,
        color: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClayColors.onSurfaceLight,
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: ClayColors.onSurfaceLight,
          ),
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

  static ThemeData _buildDark() {
    final baseText = _applyFallback(ThemeData.dark().textTheme);
    final darkText = baseText.apply(
      bodyColor: ClayColors.onSurfaceDark,
      displayColor: ClayColors.onSurfaceDark,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Noto Sans SC',
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        // Light primary for icons/accents; pair with dark onPrimary for filled controls.
        primary: ClayColors.primaryMuted,
        onPrimary: ClayColors.onPrimaryDark,
        primaryContainer: ClayColors.primaryContainerDark,
        onPrimaryContainer: ClayColors.onPrimaryContainerDark,
        secondary: ClayColors.secondaryMuted,
        onSecondary: ClayColors.onPrimaryDark,
        secondaryContainer: ClayColors.secondaryContainerDark,
        onSecondaryContainer: ClayColors.onSecondaryContainerDark,
        tertiary: ClayColors.tertiaryLight,
        onTertiary: const Color(0xFF1A1030),
        tertiaryContainer: const Color(0xFF5B3A0A),
        onTertiaryContainer: ClayColors.tertiaryLight,
        error: ClayColors.errorOnDark,
        onError: const Color(0xFF2D1010),
        errorContainer: ClayColors.errorContainerDark,
        onErrorContainer: ClayColors.onErrorContainerDark,
        surface: ClayColors.surfaceDark,
        onSurface: ClayColors.onSurfaceDark,
        onSurfaceVariant: ClayColors.onSurfaceVariantDark,
        outline: ClayColors.outlineDark,
        outlineVariant: ClayColors.outlineDark.withValues(alpha: 0.45),
        surfaceContainerLowest: const Color(0xFF080E0D),
        surfaceContainerLow: ClayColors.surfaceContainerDark,
        surfaceContainer: const Color(0xFF1A2A28),
        surfaceContainerHigh: const Color(0xFF243834),
        surfaceContainerHighest: const Color(0xFF2C433F),
      ),
      scaffoldBackgroundColor: ClayColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: ClayColors.surfaceDark,
        foregroundColor: ClayColors.onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: ClayColors.onSurfaceDark),
        actionsIconTheme: const IconThemeData(color: ClayColors.onSurfaceDark),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceDark,
          letterSpacing: -0.3,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: ClayColors.outlineDark.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClayColors.primaryMuted,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ClayColors.errorOnDark,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        filled: true,
        fillColor: ClayColors.surfaceContainerDark,
        labelStyle: TextStyle(
          color: ClayColors.onSurfaceVariantDark,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: ClayColors.onSurfaceVariantDark.withValues(alpha: 0.75),
          fontSize: 14,
        ),
        prefixIconColor: ClayColors.onSurfaceVariantDark,
        suffixIconColor: ClayColors.onSurfaceVariantDark,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
        ),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        iconColor: ClayColors.onSurfaceVariantDark,
        textColor: ClayColors.onSurfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusMd),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ClayColors.outlineDark.withValues(alpha: 0.28),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Solid brand teal + white keeps CTA readable in dark mode.
          backgroundColor: ClayColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ClayColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.onSurfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ClayColors.onSurfaceDark,
          ),
          side: BorderSide(color: ClayColors.outlineDark.withValues(alpha: 0.45)),
          backgroundColor: ClayColors.surfaceContainerDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentTextStyle: const TextStyle(
          color: ClayColors.onSurfaceDark,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        backgroundColor: const Color(0xFF2C433F),
        actionTextColor: ClayColors.primaryMuted,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ClayColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ClayColors.onSurfaceDark,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: ClayColors.onSurfaceVariantDark,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        backgroundColor: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: ClayColors.outlineDark.withValues(alpha: 0.6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        color: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(
          color: ClayColors.onSurfaceDark,
          fontSize: 14,
          fontFamily: 'Noto Sans SC',
          fontFamilyFallback: _fontFallback,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClayColors.primaryMuted,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: ClayColors.primaryMuted,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: ClayColors.onSurfaceVariantDark),
      primaryIconTheme: const IconThemeData(color: ClayColors.primaryMuted),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ClayColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: ClayColors.outlineDark.withValues(alpha: 0.55)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ClayColors.primaryMuted,
        inactiveTrackColor: ClayColors.primaryMuted.withValues(alpha: 0.22),
        thumbColor: ClayColors.primaryMuted,
        overlayColor: ClayColors.primaryMuted.withValues(alpha: 0.12),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      textTheme: darkText,
      primaryTextTheme: darkText,
    );
  }
}
