import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/service_providers.dart';
import '../../services/storage/storage_service.dart';

/// Immutable snapshot of the user's preferences.
@immutable
class AppSettings {
  final ThemeMode themeMode;
  final String userName;
  final bool ttsEnabled;
  final bool voiceEnabled;
  final double speechRate;
  final String avatarStyle; // 'anime' | 'orb'
  final String voiceName; // '' = engine default
  final String voiceLocale;
  final double voicePitch;

  const AppSettings({
    required this.themeMode,
    required this.userName,
    required this.ttsEnabled,
    required this.voiceEnabled,
    required this.speechRate,
    this.avatarStyle = 'anime',
    this.voiceName = '',
    this.voiceLocale = '',
    this.voicePitch = 1.25,
  });

  bool get animeAvatar => avatarStyle == 'anime';

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? userName,
    bool? ttsEnabled,
    bool? voiceEnabled,
    double? speechRate,
    String? avatarStyle,
    String? voiceName,
    String? voiceLocale,
    double? voicePitch,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      speechRate: speechRate ?? this.speechRate,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      voiceName: voiceName ?? this.voiceName,
      voiceLocale: voiceLocale ?? this.voiceLocale,
      voicePitch: voicePitch ?? this.voicePitch,
    );
  }
}

/// Reads/writes preferences through [StorageService] and notifies the UI so
/// theme changes, voice toggles, etc. take effect instantly.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(_loadFrom(_storage));

  final StorageService _storage;

  static AppSettings _loadFrom(StorageService s) => AppSettings(
        themeMode: s.themeMode,
        userName: s.userName,
        ttsEnabled: s.ttsEnabled,
        voiceEnabled: s.voiceEnabled,
        speechRate: s.speechRate,
        avatarStyle: s.avatarStyle,
        voiceName: s.voiceName,
        voiceLocale: s.voiceLocale,
        voicePitch: s.voicePitch,
      );

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setUserName(String name) async {
    await _storage.setUserName(name);
    state = state.copyWith(userName: name.trim());
  }

  Future<void> setTtsEnabled(bool value) async {
    await _storage.setTtsEnabled(value);
    state = state.copyWith(ttsEnabled: value);
  }

  Future<void> setVoiceEnabled(bool value) async {
    await _storage.setVoiceEnabled(value);
    state = state.copyWith(voiceEnabled: value);
  }

  Future<void> setSpeechRate(double value) async {
    await _storage.setSpeechRate(value);
    state = state.copyWith(speechRate: value);
  }

  Future<void> setAvatarStyle(String style) async {
    await _storage.setAvatarStyle(style);
    state = state.copyWith(avatarStyle: style);
  }

  Future<void> setVoice(String name, String locale) async {
    await _storage.setVoice(name, locale);
    state = state.copyWith(voiceName: name, voiceLocale: locale);
  }

  Future<void> setVoicePitch(double value) async {
    await _storage.setVoicePitch(value);
    state = state.copyWith(voicePitch: value);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(storageServiceProvider));
});
