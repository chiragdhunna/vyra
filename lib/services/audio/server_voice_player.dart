import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../core/utils/app_logger.dart';

/// Plays Vyra's neural voice — MP3 utterances synthesized on the backend
/// (Edge neural TTS) and shipped over the websocket. This is what replaces
/// the robotic device engine: a genuinely natural female voice.
///
/// One utterance at a time; [stop] cuts speech instantly (barge-in).
class ServerVoicePlayer {
  ServerVoicePlayer() {
    _player.onPlayerComplete.listen((_) => _finish());
  }

  final AudioPlayer _player = AudioPlayer();
  void Function()? _onComplete;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<bool> play(
    Uint8List mp3, {
    void Function()? onComplete,
  }) async {
    try {
      await _player.stop();
      _onComplete = onComplete;
      _playing = true;
      await _player.play(BytesSource(mp3, mimeType: 'audio/mpeg'));
      return true;
    } catch (e) {
      AppLogger.w('Server voice playback failed: $e', tag: 'Voice');
      _finish();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    _finish();
  }

  void _finish() {
    if (!_playing) return;
    _playing = false;
    final cb = _onComplete;
    _onComplete = null;
    cb?.call();
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
