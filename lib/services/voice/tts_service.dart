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

  Future<void> speak(String text) async {
    final clean = text.replaceAll(_emoji, '').trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stop() => _tts.stop();

  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);
}
