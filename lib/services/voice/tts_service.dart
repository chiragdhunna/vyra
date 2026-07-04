import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../core/utils/app_logger.dart';

/// Wraps `flutter_tts` to give Vyra a voice. Cleans emojis/tags out of text
/// before speaking and exposes start/complete callbacks so the avatar can mouth
/// along while speaking.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  // Matches most emoji / pictographic ranges so they aren't read aloud.
  static final RegExp _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}️]',
    unicode: true,
  );

  Future<void> init({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    double rate = 0.5,
  }) async {
    if (_inited) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.06);
      await _tts.setVolume(1.0);
      if (onStart != null) _tts.setStartHandler(onStart);
      if (onComplete != null) {
        _tts.setCompletionHandler(onComplete);
        _tts.setCancelHandler(onComplete);
      }
      _inited = true;
    } catch (e) {
      AppLogger.w('TTS init failed: $e', tag: 'TTS');
    }
  }

  /// English voices installed on this device, as {name, locale} pairs.
  Future<List<Map<String, String>>> englishVoices() async {
    try {
      final raw = await _tts.getVoices;
      final voices = <Map<String, String>>[];
      if (raw is List) {
        for (final v in raw) {
          if (v is Map) {
            final name = '${v['name'] ?? ''}';
            final locale = '${v['locale'] ?? ''}';
            if (name.isEmpty) continue;
            if (locale.toLowerCase().replaceAll('_', '-').startsWith('en')) {
              voices.add({'name': name, 'locale': locale});
            }
          }
        }
      }
      voices.sort((a, b) => a['name']!.compareTo(b['name']!));
      return voices;
    } catch (e) {
      AppLogger.w('getVoices failed: $e', tag: 'TTS');
      return const [];
    }
  }

  Future<void> applyVoice(String name, String locale) async {
    if (name.isEmpty) return;
    try {
      await _tts.setVoice({'name': name, 'locale': locale});
      AppLogger.d('TTS voice set: $name ($locale)', tag: 'TTS');
    } catch (e) {
      AppLogger.w('setVoice failed: $e', tag: 'TTS');
    }
  }

  /// Best-effort pick of a warm female voice from [voices].
  ///
  /// Device voice names are opaque and engine-specific, so this checks
  /// explicit female markers first, then voice codes that are female on
  /// Google's TTS engine. Returns null when unsure (the Settings > Voice
  /// picker is the reliable path — every voice can be auditioned there).
  static Map<String, String>? pickFemale(List<Map<String, String>> voices) {
    for (final v in voices) {
      if (v['name']!.toLowerCase().contains('female')) return v;
    }
    const knownFemale = [
      'en-us-x-tpa', 'en-us-x-sfg', 'en-us-x-tpc', 'en-us-x-iob',
      'en-gb-x-gba', 'en-gb-x-fis', 'en-au-x-aua', 'en-in-x-ena',
    ];
    for (final code in knownFemale) {
      for (final v in voices) {
        if (v['name']!.toLowerCase().startsWith(code)) return v;
      }
    }
    return null;
  }

  /// Speaks a short line so the user can audition a voice in the picker.
  Future<void> sample() =>
      speak("Hi! I'm Vyra. How does this voice sound?");

  Future<void> speak(String text) async {
    final clean = text.replaceAll(_emoji, '').trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stop() => _tts.stop();

  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
}
