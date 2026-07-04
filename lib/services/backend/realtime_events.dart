/// Typed events for the vyra-backend `/realtime` websocket protocol.
///
/// Wire format (mirrors `app/realtime/protocol.py` in vyra-backend):
///  * text frames  — JSON `{"type": ..., ...}` both directions
///  * binary frames — raw mic audio, PCM16 mono LE @16 kHz (client → server)
library;

import 'dart:convert';

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
  const SessionReady({
    required this.provider,
    required this.model,
    required this.serverStt,
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
  const AssistantSay({
    required this.id,
    required this.text,
    required this.emotion,
    required this.proactive,
  });
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

  static String visionState({required bool present, required bool smiling}) =>
      jsonEncode({'type': 'vision.state', 'present': present, 'smiling': smiling});

  static String userText(String text) =>
      jsonEncode({'type': 'user.text', 'text': text});

  static String ttsState({required bool playing}) =>
      jsonEncode({'type': 'tts.state', 'playing': playing});

  static String micState({required bool muted}) =>
      jsonEncode({'type': 'mic.state', 'muted': muted});

  static String ping() => jsonEncode({'type': 'ping'});
}
