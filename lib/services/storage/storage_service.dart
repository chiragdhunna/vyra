import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

/// Thin wrapper around Hive that owns Vyra's local persistence:
/// a settings box (key/value), a chat history box, and a reminders box.
///
/// Reads are synchronous (Hive keeps boxes in memory); writes return Futures
/// you can optionally await.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late final Box _settings;
  late final Box chatBox;
  late final Box reminderBox;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _settings = await Hive.openBox(AppConstants.settingsBox);
    chatBox = await Hive.openBox(AppConstants.chatBox);
    reminderBox = await Hive.openBox(AppConstants.reminderBox);
    _ready = true;
    AppLogger.d('StorageService ready', tag: 'Storage');
  }

  // --- Generic key/value ---
  T? read<T>(String key, {T? defaultValue}) =>
      _settings.get(key, defaultValue: defaultValue) as T?;

  Future<void> write(String key, dynamic value) => _settings.put(key, value);

  Future<void> remove(String key) => _settings.delete(key);

  // --- Typed settings convenience ---
  bool get onboardingDone =>
      _settings.get(AppConstants.keyOnboardingDone, defaultValue: false) as bool;
  Future<void> setOnboardingDone(bool v) =>
      _settings.put(AppConstants.keyOnboardingDone, v);

  String get userName =>
      _settings.get(AppConstants.keyUserName, defaultValue: '') as String;
  Future<void> setUserName(String v) =>
      _settings.put(AppConstants.keyUserName, v.trim());

  bool get ttsEnabled =>
      _settings.get(AppConstants.keyTtsEnabled, defaultValue: true) as bool;
  Future<void> setTtsEnabled(bool v) =>
      _settings.put(AppConstants.keyTtsEnabled, v);

  bool get voiceEnabled =>
      _settings.get(AppConstants.keyVoiceEnabled, defaultValue: true) as bool;
  Future<void> setVoiceEnabled(bool v) =>
      _settings.put(AppConstants.keyVoiceEnabled, v);

  double get speechRate =>
      (_settings.get(AppConstants.keySpeechRate, defaultValue: 0.5) as num)
          .toDouble();
  Future<void> setSpeechRate(double v) =>
      _settings.put(AppConstants.keySpeechRate, v);

  /// 'anime' (sprite character) or 'orb' (classic painter face).
  String get avatarStyle =>
      _settings.get(AppConstants.keyAvatarStyle, defaultValue: 'anime')
          as String;
  Future<void> setAvatarStyle(String v) =>
      _settings.put(AppConstants.keyAvatarStyle, v);

  String get voiceName =>
      _settings.get(AppConstants.keyVoiceName, defaultValue: '') as String;
  String get voiceLocale =>
      _settings.get(AppConstants.keyVoiceLocale, defaultValue: '') as String;
  Future<void> setVoice(String name, String locale) async {
    await _settings.put(AppConstants.keyVoiceName, name);
    await _settings.put(AppConstants.keyVoiceLocale, locale);
  }

  ThemeMode get themeMode {
    final raw =
        _settings.get(AppConstants.keyThemeMode, defaultValue: 'dark') as String;
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _settings.put(AppConstants.keyThemeMode, mode.name);
}
