import 'package:flutter/material.dart';

/// Central color palette for Vyra.
///
/// Vyra's visual identity is a "calm intelligence in deep space" — a dark,
/// violet-leaning canvas that lets the animated avatar glow with gradients of
/// violet → cyan. Emotion accents shift the glow to communicate mood.
class AppColors {
  AppColors._();

  // --- Brand ---
  static const Color primary = Color(0xFF7C5CFF); // violet
  static const Color primaryDeep = Color(0xFF5B3FD9);
  static const Color primarySoft = Color(0xFFA48BFF);
  static const Color accent = Color(0xFF2DD4FF); // cyan
  static const Color accentDeep = Color(0xFF0EA5E9);
  static const Color accentPink = Color(0xFFFF5CA8);

  // --- Backgrounds (dark, the default for Vyra) ---
  static const Color bgDark = Color(0xFF0D0B1A);
  static const Color bgDarkAlt = Color(0xFF14102A);
  static const Color surface = Color(0xFF1B1638);
  static const Color surfaceAlt = Color(0xFF241D4A);
  static const Color surfaceGlass = Color(0x33241D4A);

  // --- Backgrounds (light) ---
  static const Color bgLight = Color(0xFFF6F4FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightAlt = Color(0xFFEDE9FF);

  // --- Text ---
  static const Color textPrimary = Color(0xFFF4F2FF);
  static const Color textSecondary = Color(0xFFB6AEDC);
  static const Color textMuted = Color(0xFF6F6790);
  static const Color textOnLight = Color(0xFF1B1638);

  // --- Semantic ---
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFB7185);

  // --- Gradients ---
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

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [bgDark, bgDarkAlt],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
