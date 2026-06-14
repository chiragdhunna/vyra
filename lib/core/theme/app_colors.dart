import 'package:flutter/material.dart';

/// Central color palette for Vyra.
///
/// Vyra's visual identity is a "calm intelligence in deep space" — a violet-
/// leaning canvas that lets the animated avatar glow with gradients of
/// violet → cyan. The brand hues (violet/cyan/pink) are shared across themes;
/// the **surfaces and text** flip with the active theme.
///
/// Light mode used to do almost nothing because every screen painted the dark
/// surface/gradient/text tokens directly (issue #7). To fix that without
/// rewriting ~100 call sites, the surface + text tokens below are now
/// brightness-aware getters that resolve against [brightness], which the root
/// widget sets to the live theme brightness on every build. `AppTextStyles`
/// reads its colors from these getters too, so typography adapts automatically.
///
/// `AppTheme` builds each [ThemeData] from the explicit per-brightness
/// constants (the `*Dark` / light-named ones) so theme construction never
/// depends on the global, only the screen-facing getters do.
class AppColors {
  AppColors._();

  /// The active brightness, set by the app root (see `VyraApp.build`) before any
  /// screen builds. Defaults to dark — Vyra's signature look.
  static Brightness brightness = Brightness.dark;
  static bool get _isLight => brightness == Brightness.light;

  /// Syncs the active brightness from the inherited [Theme] and returns it.
  ///
  /// Call at the very top of a widget's `build()`: it both registers a
  /// dependency on the Theme (so the widget rebuilds when the user flips
  /// light/dark mid-session) and refreshes the brightness-aware tokens for the
  /// reads that follow. Without it, screens that don't otherwise consume
  /// `Theme.of(context)` keep painting the previous theme until the next app
  /// launch (issue #7).
  static Brightness sync(BuildContext context) =>
      brightness = Theme.of(context).brightness;

  // --- Brand (shared across themes) ---
  static const Color primary = Color(0xFF7C5CFF); // violet
  static const Color primaryDeep = Color(0xFF5B3FD9);
  static const Color primarySoft = Color(0xFFA48BFF);
  static const Color accent = Color(0xFF2DD4FF); // cyan
  static const Color accentDeep = Color(0xFF0EA5E9);
  static const Color accentPink = Color(0xFFFF5CA8);

  // --- Raw dark surfaces ---
  static const Color bgDark = Color(0xFF0D0B1A);
  static const Color bgDarkAlt = Color(0xFF14102A);
  static const Color surfaceDark = Color(0xFF1B1638);
  static const Color surfaceDarkAlt = Color(0xFF241D4A);
  static const Color surfaceDarkGlass = Color(0x33241D4A);

  // --- Raw light surfaces ---
  static const Color bgLight = Color(0xFFF6F4FF);
  static const Color bgLightAlt = Color(0xFFEDE9FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightAlt = Color(0xFFEDE9FF);
  static const Color surfaceLightGlass = Color(0x80FFFFFF);

  // --- Raw text colors ---
  static const Color textDarkPrimary = Color(0xFFF4F2FF);
  static const Color textDarkSecondary = Color(0xFFB6AEDC);
  static const Color textDarkMuted = Color(0xFF6F6790);
  static const Color textOnLight = Color(0xFF1B1638);
  static const Color textLightSecondary = Color(0xFF5B5478);
  static const Color textLightMuted = Color(0xFF8B84A6);

  // --- Surfaces (brightness-aware, used by screens) ---
  static Color get surface => _isLight ? surfaceLight : surfaceDark;
  static Color get surfaceAlt => _isLight ? surfaceLightAlt : surfaceDarkAlt;
  static Color get surfaceGlass =>
      _isLight ? surfaceLightGlass : surfaceDarkGlass;

  // --- Text (brightness-aware, used by screens + AppTextStyles) ---
  static Color get textPrimary => _isLight ? textOnLight : textDarkPrimary;
  static Color get textSecondary =>
      _isLight ? textLightSecondary : textDarkSecondary;
  static Color get textMuted => _isLight ? textLightMuted : textDarkMuted;

  // --- Semantic (shared) ---
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFB7185);

  // --- Gradients (shared brand) ---
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient auroraGradient = LinearGradient(
    colors: [primaryDeep, primary, accent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const RadialGradient avatarGlow = RadialGradient(
    colors: [primarySoft, primary, primaryDeep],
    radius: 0.85,
  );

  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [bgDark, bgDarkAlt],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    colors: [bgLight, bgLightAlt],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// The full-screen background gradient for the current theme.
  static LinearGradient get backgroundGradient =>
      _isLight ? backgroundGradientLight : backgroundGradientDark;
}
