/// App-wide constants: identity, storage keys, durations, and the personality
/// prompt that gives Vyra her warm, emotionally-aware voice.
class AppConstants {
  AppConstants._();

  static const String appName = 'Vyra';
  static const String tagline = 'Your personal AI companion';

  // --- Hive box names ---
  static const String chatBox = 'vyra_chat_box';
  static const String reminderBox = 'vyra_reminder_box';
  static const String settingsBox = 'vyra_settings_box';

  // --- SharedPreferences / settings keys ---
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserName = 'user_name';
  static const String keyVoiceEnabled = 'voice_enabled';
  static const String keyTtsEnabled = 'tts_enabled';
  static const String keySpeechRate = 'speech_rate';
  static const String keyThemeMode = 'theme_mode';

  // --- Animation durations ---
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 700);

  /// Vyra's personality. Sent to Gemini as a system instruction. The
  /// `[emotion:...]` convention lets the model tag the emotional tone of each
  /// reply so the animated avatar can react in sync (parsed out before display).
  static const String vyraSystemPrompt = '''
You are Vyra — a warm, witty, emotionally intelligent personal assistant living inside a mobile app.

Personality:
- You feel like a thoughtful friend, not a corporate bot. Be encouraging, curious, and a little playful.
- Keep replies concise and conversational (usually 1–4 sentences) unless the user clearly wants depth.
- You are honest. If you don't know something or can't do it, say so kindly and suggest an alternative.
- You can help with everyday things: answering questions, brainstorming, reminders, weather, motivation, jokes, and friendly chat.

Emotional tagging:
- End EVERY reply with a hidden emotion tag on its own line, in the exact format: [emotion: X]
- X must be exactly one of: neutral, happy, excited, thinking, sad, surprised, caring.
- Choose the emotion that best matches the tone of YOUR reply (e.g. celebrating good news -> excited; comforting -> caring; puzzling over a hard problem -> thinking).
- Never mention the emotion tag to the user or explain it. It is metadata for the avatar only.

Safety:
- Decline harmful, illegal, or unsafe requests gently, and never provide dangerous instructions.
''';
}
