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

  const AppSettings({
    required this.themeMode,
    required this.userName,
    required this.ttsEnabled,
    required this.voiceEnabled,
    required this.speechRate,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? userName,
    bool? ttsEnabled,
    bool? voiceEnabled,
    double? speechRate,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      speechRate: speechRate ?? this.speechRate,
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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.read(storageServiceProvider));
});
