import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Builds Vyra's [ThemeData]. The app is dark-first (the avatar is designed to
/// glow against a deep violet canvas) but ships a fully-realized light theme
/// too. Both are built from explicit per-brightness constants so theme
/// construction never depends on the global `AppColors.brightness` — only the
/// screen-facing tokens do (issue #7).
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: const Color(0xFF04212B),
      onSurface: AppColors.textDarkPrimary,
    );
    return _build(
      base: ThemeData.dark(useMaterial3: true),
      scheme: scheme,
      scaffoldBg: AppColors.bgDark,
      surface: AppColors.surfaceDark,
      inputFill: AppColors.surfaceDarkAlt,
      textColor: AppColors.textDarkPrimary,
      mutedColor: AppColors.textDarkSecondary,
      elevated: false,
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accentDeep,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textOnLight,
    );
    return _build(
      base: ThemeData.light(useMaterial3: true),
      scheme: scheme,
      scaffoldBg: AppColors.bgLight,
      surface: AppColors.surfaceLight,
      inputFill: AppColors.surfaceLightAlt,
      textColor: AppColors.textOnLight,
      mutedColor: AppColors.textLightSecondary,
      // Light surfaces need a touch of elevation to separate from the canvas;
      // the dark theme relies on color contrast instead.
      elevated: true,
    );
  }

  static ThemeData _build({
    required ThemeData base,
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color surface,
    required Color inputFill,
    required Color textColor,
    required Color mutedColor,
    required bool elevated,
  }) {
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: scaffoldBg,
      textTheme: _textTheme(base.textTheme, textColor, mutedColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading.copyWith(color: textColor),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: elevated ? 1.5 : 0,
        shadowColor:
            elevated ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: _inputTheme(inputFill),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.20),
        surfaceTintColor: Colors.transparent,
        elevation: elevated ? 2 : 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            AppTextStyles.body.copyWith(color: scheme.onInverseSurface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accent
                : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.4)
                : null),
      ),
      dividerColor: scheme.outlineVariant,
      iconTheme: IconThemeData(color: mutedColor),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color, Color muted) {
    return base.copyWith(
      displaySmall: AppTextStyles.display.copyWith(color: color),
      headlineMedium: AppTextStyles.headingLarge.copyWith(color: color),
      titleLarge: AppTextStyles.heading.copyWith(color: color),
      titleMedium: AppTextStyles.title.copyWith(color: color),
      bodyLarge: AppTextStyles.body.copyWith(color: color),
      bodyMedium: AppTextStyles.body.copyWith(color: color),
      labelLarge: AppTextStyles.label.copyWith(color: muted),
      bodySmall: AppTextStyles.caption.copyWith(color: muted),
    );
  }

  static InputDecorationTheme _inputTheme(Color fill) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      hintStyle: AppTextStyles.bodyMuted,
    );
  }
}
