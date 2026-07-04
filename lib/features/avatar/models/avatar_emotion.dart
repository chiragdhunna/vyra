import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The emotional states Vyra's animated face can express. These map 1:1 to the
/// `[emotion: X]` tags Gemini appends to each reply (see [AvatarEmotion.fromTag]).
enum AvatarEmotion {
  neutral,
  happy,
  excited,
  thinking,
  sad,
  surprised,
  caring,
  cry,
  angry;

  /// Parses an emotion tag string (case-insensitive) into an [AvatarEmotion],
  /// falling back to [neutral] for anything unrecognized.
  static AvatarEmotion fromTag(String? tag) {
    if (tag == null) return AvatarEmotion.neutral;
    final t = tag.toLowerCase().trim();
    return AvatarEmotion.values.firstWhere(
      (e) => e.name == t,
      orElse: () => AvatarEmotion.neutral,
    );
  }

  /// Core glow color used for the orb body and outer aura.
  Color get color => switch (this) {
        AvatarEmotion.neutral => AppColors.primary,
        AvatarEmotion.happy => const Color(0xFF36D1A6),
        AvatarEmotion.excited => AppColors.accentPink,
        AvatarEmotion.thinking => const Color(0xFF5B8DEF),
        AvatarEmotion.sad => const Color(0xFF6C7DD8),
        AvatarEmotion.surprised => const Color(0xFFFFC857),
        AvatarEmotion.caring => const Color(0xFFFF8FB1),
        AvatarEmotion.cry => const Color(0xFF4F6BD8),
        AvatarEmotion.angry => const Color(0xFFE4574B),
      };

  /// Secondary color blended into the orb gradient + particles.
  Color get accent => switch (this) {
        AvatarEmotion.neutral => AppColors.accent,
        AvatarEmotion.happy => const Color(0xFFB6F09C),
        AvatarEmotion.excited => const Color(0xFFFFD166),
        AvatarEmotion.thinking => AppColors.accent,
        AvatarEmotion.sad => const Color(0xFF8FA0E0),
        AvatarEmotion.surprised => const Color(0xFFFF6B6B),
        AvatarEmotion.caring => const Color(0xFFFFC2D6),
        AvatarEmotion.cry => const Color(0xFF8FB3FF),
        AvatarEmotion.angry => const Color(0xFFFF9E58),
      };

  String get label => name[0].toUpperCase() + name.substring(1);

  String get emoji => switch (this) {
        AvatarEmotion.neutral => '🙂',
        AvatarEmotion.happy => '😊',
        AvatarEmotion.excited => '🤩',
        AvatarEmotion.thinking => '🤔',
        AvatarEmotion.sad => '😔',
        AvatarEmotion.surprised => '😮',
        AvatarEmotion.caring => '🥰',
        AvatarEmotion.cry => '😭',
        AvatarEmotion.angry => '😠',
      };
}
