import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/app_logger.dart';

/// Wraps `speech_to_text` for real-time microphone transcription. Reports
/// partial + final results and live sound levels (used to animate the avatar
/// and the waveform while listening).
class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _stt = SpeechToText();
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  Future<bool> init({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    try {
      _available = await _stt.initialize(
        onStatus: (s) => onStatus?.call(s),
        onError: (e) {
          AppLogger.w('STT error: ${e.errorMsg}', tag: 'STT');
          onError?.call(e.errorMsg);
        },
      );
    } catch (e) {
      AppLogger.w('STT init failed: $e', tag: 'STT');
      _available = false;
    }
    return _available;
  }

  Future<void> listen({
    required ValueChanged<String> onPartial,
    required ValueChanged<String> onFinal,
    ValueChanged<double>? onLevel,
  }) async {
    if (!_available) return;
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          onFinal(result.recognizedWords);
        } else {
          onPartial(result.recognizedWords);
        }
      },
      onSoundLevelChange: onLevel,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      ),
    );
  }

  Future<void> stop() => _stt.stop();
  Future<void> cancel() => _stt.cancel();
}
