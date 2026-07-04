/// Typed events for the vyra-backend `/realtime` websocket protocol.
///
/// Wire format (mirrors `app/realtime/protocol.py` in vyra-backend):
///  * text frames  — JSON `{"type": ..., ...}` both directions
///  * binary frames — raw mic audio, PCM16 mono LE @16 kHz (client → server)
library;

import 'dart:convert';
import 'dart:typed_data';

/// What Vyra's brain is doing right now (server-driven).
enum CompanionPhase { connecting, listening, thinking, speaking, idle, offline }

CompanionPhase phaseFromWire(String value) => switch (value) {
      'listening' => CompanionPhase.listening,
      'thinking' => CompanionPhase.thinking,
      'speaking' => CompanionPhase.speaking,
      'idle' => CompanionPhase.idle,
      _ => CompanionPhase.listening,
    };

/// A parsed server → client event.
sealed class RealtimeEvent {
  const RealtimeEvent();

  static RealtimeEvent? decode(String raw) {
    final Object? data;
    try {
      data = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (data is! Map) return null;
    final map = data.cast<String, dynamic>();
    switch (map['type'] as String? ?? '') {
      case 'session.ready':
        return SessionReady(
          provider: (map['provider'] as String?) ?? '?',
          model: (map['model'] as String?) ?? '?',
          serverStt: map['stt'] == 'server',
          serverTts: map['tts'] == 'server',
          visionFrames: (map['vision_frames'] as bool?) ?? false,
          frameIntervalSeconds:
              (map['vision_frame_interval'] as num?)?.toDouble() ?? 20.0,
        );
      case 'state':
        return StateChanged(phaseFromWire((map['value'] as String?) ?? ''));
      case 'user.final':
        return UserFinal((map['text'] as String?) ?? '');
      case 'assistant.say':
        return AssistantSay(
          id: (map['id'] as num?)?.toInt() ?? 0,
          text: (map['text'] as String?) ?? '',
          emotion: (map['emotion'] as String?) ?? 'neutral',
          proactive: (map['proactive'] as bool?) ?? false,
          gesture: (map['gesture'] as String?) ?? '',
        );
      case 'assistant.audio':
        return AssistantAudio(
          id: (map['id'] as num?)?.toInt() ?? 0,
          audio: (map['audio_b64'] as String?) is String &&
                  (map['audio_b64'] as String).isNotEmpty
              ? base64Decode(map['audio_b64'] as String)
              : null,
        );
      case 'tts.interrupt':
        return TtsInterrupt((map['id'] as num?)?.toInt() ?? 0);
      case 'error':
        return ServerError((map['message'] as String?) ?? 'unknown error');
      case 'pong':
        return const Pong();
      default:
        return null; // forward-compatible: ignore unknown events
    }
  }
}

class SessionReady extends RealtimeEvent {
  final String provider;
  final String model;
  final bool serverStt;

  /// Her voice is synthesized on the backend (neural) vs device TTS.
  final bool serverTts;

  /// The backend has a vision LLM: send periodic frame glimpses.
  final bool visionFrames;
  final double frameIntervalSeconds;

  const SessionReady({
    required this.provider,
    required this.model,
    required this.serverStt,
    this.serverTts = false,
    this.visionFrames = false,
    this.frameIntervalSeconds = 20.0,
  });
}

class StateChanged extends RealtimeEvent {
  final CompanionPhase phase;
  const StateChanged(this.phase);
}

class UserFinal extends RealtimeEvent {
  final String text;
  const UserFinal(this.text);
}

class AssistantSay extends RealtimeEvent {
  final int id;
  final String text;
  final String emotion;
  final bool proactive;

  /// Optional pose the avatar should play with this line (wave, laugh, …).
  final String gesture;

  const AssistantSay({
    required this.id,
    required this.text,
    required this.emotion,
    required this.proactive,
    this.gesture = '',
  });
}

/// Her synthesized voice for one say-id. [audio] == null means synthesis
/// failed server-side — play the line with device TTS instead.
class AssistantAudio extends RealtimeEvent {
  final int id;
  final Uint8List? audio;
  const AssistantAudio({required this.id, this.audio});
}

class TtsInterrupt extends RealtimeEvent {
  final int id;
  const TtsInterrupt(this.id);
}

class ServerError extends RealtimeEvent {
  final String message;
  const ServerError(this.message);
}

class Pong extends RealtimeEvent {
  const Pong();
}

/// Client → server event encoders.
abstract final class ClientEvents {
  static String sessionStart({
    String? userName,
    int sampleRate = 16000,
    bool greet = true,
    bool clientStt = false,
  }) =>
      jsonEncode({
        'type': 'session.start',
        if (userName != null && userName.isNotEmpty) 'user_name': userName,
        'sample_rate': sampleRate,
        'greet': greet,
        'client_stt': clientStt,
      });

  static String visionState({
    required bool present,
    required bool smiling,
    double eyesOpen = 1.0,
  }) =>
      jsonEncode({
        'type': 'vision.state',
        'present': present,
        'smiling': smiling,
        'eyes_open': double.parse(eyesOpen.toStringAsFixed(2)),
      });

  static String visionFrame(Uint8List jpeg) => jsonEncode({
        'type': 'vision.frame',
        'jpeg_b64': base64Encode(jpeg),
      });

  static String userText(String text) =>
      jsonEncode({'type': 'user.text', 'text': text});

  static String ttsState({required bool playing}) =>
      jsonEncode({'type': 'tts.state', 'playing': playing});

  static String micState({required bool muted}) =>
      jsonEncode({'type': 'mic.state', 'muted': muted});

  static String ping() => jsonEncode({'type': 'ping'});
}
