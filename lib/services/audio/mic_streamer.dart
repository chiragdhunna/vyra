import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../core/utils/app_logger.dart';

/// Continuous microphone capture for the realtime companion.
///
/// Unlike `speech_to_text` (turn-based: opens, endpoints, closes), this
/// streams raw PCM16 mono @16 kHz for as long as the companion screen is
/// up — the backend's VAD decides when you started and stopped talking,
/// which is what makes interrupt-anytime conversation possible.
///
/// Echo control matters here: the mic stays open while Vyra talks through
/// the phone speaker. We request the platform's voice-communication path
/// with hardware echo cancellation + noise suppression, and the backend
/// adds a stricter barge-in threshold on top.
class MicStreamer {
  MicStreamer({this.sampleRate = 16000});

  final int sampleRate;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  bool _running = false;

  bool get isRunning => _running;

  /// Starts streaming; [onAudio] receives raw PCM16 chunks.
  /// Returns false when the mic permission is missing/denied.
  Future<bool> start(void Function(Uint8List pcm) onAudio) async {
    if (_running) return true;
    try {
      if (!await _recorder.hasPermission()) {
        AppLogger.w('Mic permission not granted', tag: 'Mic');
        return false;
      }
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
          androidConfig: const AndroidRecordConfig(
            audioSource: AndroidAudioSource.voiceCommunication,
          ),
        ),
      );
      _subscription = stream.listen(
        onAudio,
        onError: (Object e) =>
            AppLogger.w('Mic stream error: $e', tag: 'Mic'),
      );
      _running = true;
      return true;
    } catch (e, st) {
      AppLogger.e('Mic stream start failed', error: e, stackTrace: st, tag: 'Mic');
      _running = false;
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
