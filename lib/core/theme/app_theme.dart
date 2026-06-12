import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Builds Vyra's [ThemeData]. The app is dark-first (the avatar is designed to
/// glow against a deep violet canvas) but a light theme is provided too.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Color(0xFF04212B),
      onSurface: AppColors.textPrimary,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgDark,
      canvasColor: AppColors.bgDark,
      textTheme: _textTheme(base.textTheme, AppColors.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: _inputTheme(AppColors.surfaceAlt),
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: AppColors.surfaceAlt,
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accentDeep,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textOnLight,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: _textTheme(base.textTheme, AppColors.textOnLight),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading.copyWith(color: AppColors.textOnLight),
        iconTheme: const IconThemeData(color: AppColors.textOnLight),
      ),
      inputDecorationTheme: _inputTheme(AppColors.surfaceLightAlt),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) {
    return base.copyWith(
      displaySmall: AppTextStyles.display.copyWith(color: color),
      headlineMedium: AppTextStyles.headingLarge.copyWith(color: color),
      titleLarge: AppTextStyles.heading.copyWith(color: color),
      titleMedium: AppTextStyles.title.copyWith(color: color),
      bodyLarge: AppTextStyles.body.copyWith(color: color),
      bodyMedium: AppTextStyles.body.copyWith(color: color),
      labelLarge: AppTextStyles.label,
      bodySmall: AppTextStyles.caption,
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
