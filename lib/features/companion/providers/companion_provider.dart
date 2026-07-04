import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../services/audio/mic_streamer.dart';
import '../../../services/backend/realtime_client.dart';
import '../../../services/backend/realtime_events.dart';
import '../../../services/service_providers.dart';
import '../../avatar/models/avatar_emotion.dart';
import '../../avatar/providers/avatar_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../../vision/providers/vision_provider.dart';
import '../../voice/providers/voice_provider.dart';

/// How the companion is powered.
enum CompanionMode {
  /// vyra-backend with server-side ears: continuous mic streaming, true
  /// interrupt-anytime conversation (the endgame).
  backendLive,

  /// vyra-backend brain, but on-device turn-based STT (backend has no
  /// whisper installed). Still gets the backend's model + proactivity.
  backendHybrid,

  /// No backend configured: the original on-device loop (Gemini direct).
  standalone,
}

@immutable
class CompanionState {
  final CompanionMode mode;
  final CompanionPhase phase;
  final RealtimeStatus connection;
  final String brainLabel; // e.g. "ollama · llama3.1", "Gemini (on-device key)"
  final String caption; // last spoken line (hers) shown under the avatar
  final bool micMuted;

  const CompanionState({
    this.mode = CompanionMode.standalone,
    this.phase = CompanionPhase.connecting,
    this.connection = RealtimeStatus.disconnected,
    this.brainLabel = '',
    this.caption = "Hey! I'm right here — let's talk.",
    this.micMuted = false,
  });

  bool get backendMode => mode != CompanionMode.standalone;
  bool get online =>
      !backendMode || connection == RealtimeStatus.connected;

  CompanionState copyWith({
    CompanionMode? mode,
    CompanionPhase? phase,
    RealtimeStatus? connection,
    String? brainLabel,
    String? caption,
    bool? micMuted,
  }) =>
      CompanionState(
        mode: mode ?? this.mode,
        phase: phase ?? this.phase,
        connection: connection ?? this.connection,
        brainLabel: brainLabel ?? this.brainLabel,
        caption: caption ?? this.caption,
        micMuted: micMuted ?? this.micMuted,
      );
}

/// The conductor of the companion experience. One brain, three modes:
/// it owns the realtime socket + continuous mic when a backend is
/// configured, or drives the classic turn-based loop standalone — and in
/// every mode it keeps the avatar, captions and turn-taking in sync.
class CompanionController extends StateNotifier<CompanionState> {
  CompanionController(this._ref) : super(const CompanionState());

  final Ref _ref;

  RealtimeClient? _client;
  MicStreamer? _mic;
  Timer? _tick;
  final math.Random _rng = math.Random();

  bool _running = false;
  bool _foreground = true;
  bool _lastPresent = false;
  bool _lastSmiling = false;
  double _lastEyesOpen = 1.0;
  bool _spokeOnce = false;
  int _nudges = 0;
  DateTime _lastInteraction = DateTime.now();
  DateTime _lastSmileReact = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastListenStart = DateTime.fromMillisecondsSinceEpoch(0);

  static const _standaloneGreetings = [
    'Hey, there you are! So good to see you.',
    'Oh, hi! Lovely to see you.',
    'There you are — how are you doing?',
    'Hey friend! Good to see your face.',
  ];
  static const _standaloneSmileLines = [
    'I love that smile!',
    'That smile makes my day!',
    'Aww, you look happy!',
  ];
  static const _standaloneOpeners = [
    "So, what's on your mind today?",
    'How are you really doing?',
    'Tell me something good that happened recently.',
    'What have you been up to lately?',
    'Got anything fun coming up?',
  ];

  AvatarController get _avatar => _ref.read(avatarControllerProvider.notifier);
  VoiceController get _voice => _ref.read(voiceControllerProvider.notifier);
  bool get _ttsOn => _ref.read(settingsProvider).ttsEnabled;

  // ------------------------------------------------------------------ //
  // Lifecycle (driven by the screen)
  // ------------------------------------------------------------------ //
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _foreground = true;
    _lastInteraction = DateTime.now();

    if (Env.hasBackend) {
      state = state.copyWith(
        mode: CompanionMode.backendLive,
        phase: CompanionPhase.connecting,
        brainLabel: 'connecting…',
        caption: 'Waking up my brain…',
      );
      _client = RealtimeClient(onEvent: _onEvent, onStatus: _onStatus);
      await _client!.connect(
        userName: _ref.read(storageServiceProvider).userName,
        greet: true,
      );
    } else {
      state = state.copyWith(
        mode: CompanionMode.standalone,
        phase: CompanionPhase.listening,
        brainLabel: _ref.read(aiEngineProvider).label,
      );
      _avatar.react(AvatarEmotion.caring);
      // Break the ice quickly, VisionScreen-style, then open the mic.
      _lastInteraction =
          DateTime.now().subtract(const Duration(seconds: 12));
    }
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 2), (_) => _onTick());
  }

  Future<void> stop() async {
    _running = false;
    _tick?.cancel();
    _tick = null;
    await _stopMic();
    await _client?.close();
    _client = null;
    await _voice.stopListening();
    await _voice.stopSpeaking();
    _avatar.idle();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) {
      _stopMic();
      _voice.stopListening();
    } else if (_running && state.mode == CompanionMode.backendLive) {
      _startMicIfNeeded();
    }
  }

  // ------------------------------------------------------------------ //
  // Backend events
  // ------------------------------------------------------------------ //
  void _onStatus(RealtimeStatus status) {
    if (!mounted) return;
    state = state.copyWith(
      connection: status,
      phase: status == RealtimeStatus.connected
          ? state.phase
          : CompanionPhase.offline,
      caption: status == RealtimeStatus.connected
          ? state.caption
          : "Trying to reach my brain… is the backend running on your Wi-Fi?",
    );
    if (status != RealtimeStatus.connected) _stopMic();
  }

  void _onEvent(RealtimeEvent event) {
    if (!mounted) return;
    switch (event) {
      case SessionReady(:final provider, :final model, :final serverStt):
        state = state.copyWith(
          mode: serverStt
              ? CompanionMode.backendLive
              : CompanionMode.backendHybrid,
          brainLabel: '$provider · $model',
          phase: CompanionPhase.listening,
          caption: "I'm here. Talk to me whenever you like.",
        );
        if (serverStt) {
          _startMicIfNeeded();
        } else {
          _armDeviceListening();
        }
      case StateChanged(:final phase):
        state = state.copyWith(phase: phase);
        switch (phase) {
          case CompanionPhase.listening:
            _avatar.setActivity(AvatarActivity.listening);
            if (state.mode == CompanionMode.backendHybrid) {
              _armDeviceListening();
            }
          case CompanionPhase.thinking:
            _avatar.setActivity(AvatarActivity.thinking);
          case CompanionPhase.speaking:
            break; // VoiceController flips the avatar when TTS actually starts
          case CompanionPhase.idle:
            _avatar.idle();
          default:
            break;
        }
      case UserFinal(:final text):
        _lastInteraction = DateTime.now();
        state = state.copyWith(caption: 'You: $text');
      case AssistantSay(:final text, :final emotion, :final gesture):
        _lastInteraction = DateTime.now();
        _spokeOnce = true;
        state = state.copyWith(caption: text);
        _avatar.react(AvatarEmotion.fromTag(emotion));
        if (gesture.isNotEmpty) {
          _avatar.playGesture(gesture,
              duration: const Duration(milliseconds: 3200));
        }
        if (_ttsOn) {
          _voice.speak(text); // isSpeaking transitions report tts.state
        } else {
          // Nothing will play: tell the server immediately so it doesn't
          // wait for a TTS that never starts.
          _client?.sendTtsState(playing: false);
          if (state.mode == CompanionMode.backendHybrid) {
            Future.delayed(const Duration(milliseconds: 600),
                _armDeviceListening);
          }
        }
      case TtsInterrupt():
        _voice.stopSpeaking();
      case ServerError(:final message):
        AppLogger.w('Backend error: $message', tag: 'Companion');
      case Pong():
        break;
    }
  }

  // ------------------------------------------------------------------ //
  // Microphone paths
  // ------------------------------------------------------------------ //
  Future<void> _startMicIfNeeded() async {
    if (state.mode != CompanionMode.backendLive ||
        state.micMuted ||
        !_foreground ||
        !_running) {
      return;
    }
    _mic ??= MicStreamer();
    if (_mic!.isRunning) return;
    final ok = await _mic!.start(_onPcm);
    if (!ok && mounted) {
      state = state.copyWith(
        caption: 'I need microphone access to hear you — check permissions?',
      );
    }
  }

  Future<void> _stopMic() async {
    await _mic?.stop();
  }

  void _onPcm(Uint8List pcm) {
    _client?.sendAudio(pcm);
    // Cheap RMS so her face pulses with your voice while listening.
    // Samples are read byte-wise (little-endian int16): the `record` plugin
    // hands out views into a larger buffer whose offsetInBytes is often NOT
    // 2-byte aligned, so ByteBuffer.asInt16List would throw a RangeError.
    if (state.phase == CompanionPhase.listening && pcm.length >= 2) {
      var acc = 0.0;
      var count = 0;
      // Sample every 8th frame (16 bytes) — plenty for an animation level.
      for (var i = 0; i + 1 < pcm.length; i += 16) {
        final v = (pcm[i] | (pcm[i + 1] << 8)).toSigned(16).toDouble();
        acc += v * v;
        count++;
      }
      if (count > 0) {
        final rms = math.sqrt(acc / count) / 32768.0;
        _avatar.setAmplitude((rms * 6).clamp(0.05, 1.0).toDouble());
      }
    }
  }

  /// Turn-based device mic (hybrid + standalone modes).
  void _armDeviceListening() {
    if (!_running || !_foreground || state.micMuted) return;
    final voice = _ref.read(voiceControllerProvider);
    final responding = state.mode == CompanionMode.standalone &&
        _ref.read(chatControllerProvider).isResponding;
    if (voice.isListening ||
        voice.isSpeaking ||
        responding ||
        !voice.sttAvailable) {
      return;
    }
    if (DateTime.now().difference(_lastListenStart) <
        const Duration(milliseconds: 800)) {
      return;
    }
    _lastListenStart = DateTime.now();
    _voice.startListening(onFinal: _onDeviceHeard);
  }

  void _onDeviceHeard(String text) {
    _nudges = 0;
    _lastInteraction = DateTime.now();
    if (state.mode == CompanionMode.backendHybrid) {
      state = state.copyWith(caption: 'You: $text');
      _client?.sendUserText(text);
    } else {
      _ref.read(chatControllerProvider.notifier).send(text);
    }
  }

  // ------------------------------------------------------------------ //
  // Cross-provider wiring (installed by the provider below)
  // ------------------------------------------------------------------ //
  void onVoiceChanged(VoiceState? previous, VoiceState next) {
    if (!_running) return;
    final wasSpeaking = previous?.isSpeaking ?? false;
    if (state.backendMode) {
      if (!wasSpeaking && next.isSpeaking) {
        _client?.sendTtsState(playing: true);
      } else if (wasSpeaking && !next.isSpeaking) {
        _client?.sendTtsState(playing: false);
      }
    } else if (wasSpeaking && !next.isSpeaking) {
      // Standalone: her turn ended → the floor is yours again.
      _armDeviceListening();
    }
  }

  void onChatChanged(dynamic previous, dynamic next) {
    if (!_running || state.mode != CompanionMode.standalone) return;
    final msgs = _ref.read(chatControllerProvider).messages;
    for (final m in msgs.reversed) {
      if (!m.isUser) {
        _lastInteraction = DateTime.now();
        _spokeOnce = true;
        if (mounted && state.caption != m.text) {
          state = state.copyWith(caption: m.text);
        }
        // With TTS off there's no speak-complete event to reopen the mic.
        if (!_ttsOn) {
          Future.delayed(const Duration(milliseconds: 600),
              _armDeviceListening);
        }
        break;
      }
    }
  }

  void onVisionChanged(VisionState? previous, VisionState next) {
    if (!_running) return;
    final present = next.faceCount > 0;
    final smiling = next.smileProbability > 0.6;

    if (state.backendMode) {
      final eyes = next.eyesOpen;
      final eyesChanged = (eyes - _lastEyesOpen).abs() > 0.15;
      if (present != _lastPresent || smiling != _lastSmiling || eyesChanged) {
        _lastPresent = present;
        _lastSmiling = smiling;
        _lastEyesOpen = eyes;
        _client?.sendVision(
            present: present, smiling: smiling, eyesOpen: eyes);
      }
      return;
    }

    // Standalone: light canned reactions (the backend does this via LLM).
    if (present && !_lastPresent && !_spokeOnce) {
      _sayStandalone(
        _standaloneGreetings[_rng.nextInt(_standaloneGreetings.length)],
        AvatarEmotion.happy,
      );
    } else if (present &&
        smiling &&
        DateTime.now().difference(_lastSmileReact) >
            const Duration(seconds: 12)) {
      _lastSmileReact = DateTime.now();
      _sayStandalone(
        _standaloneSmileLines[_rng.nextInt(_standaloneSmileLines.length)],
        AvatarEmotion.excited,
      );
    }
    _lastPresent = present;
    _lastSmiling = smiling;
  }

  // ------------------------------------------------------------------ //
  // Standalone proactivity (backend modes get this server-side)
  // ------------------------------------------------------------------ //
  void _onTick() {
    if (!_running || !_foreground || state.micMuted) return;
    if (state.mode == CompanionMode.standalone) {
      final voice = _ref.read(voiceControllerProvider);
      final responding = _ref.read(chatControllerProvider).isResponding;
      if (voice.isListening || voice.isSpeaking || responding) return;
      if (_nudges >= 3) return; // she's said enough; wait for the user
      if (DateTime.now().difference(_lastInteraction) >=
          const Duration(seconds: 15)) {
        _nudges++;
        _sayStandalone(
          _standaloneOpeners[_rng.nextInt(_standaloneOpeners.length)],
          _rng.nextBool() ? AvatarEmotion.happy : AvatarEmotion.caring,
        );
      }
      // Keep the mic armed for the user's turn between nudges.
      _armDeviceListening();
    }
  }

  void _sayStandalone(String line, AvatarEmotion emotion) {
    if (!mounted) return;
    _spokeOnce = true;
    _lastInteraction = DateTime.now();
    state = state.copyWith(caption: line);
    _avatar.react(emotion);
    _voice.speak(line);
    if (!_ttsOn) {
      Future.delayed(const Duration(milliseconds: 700), _armDeviceListening);
    }
  }

  // ------------------------------------------------------------------ //
  // User controls
  // ------------------------------------------------------------------ //
  Future<void> toggleMute() async {
    final muted = !state.micMuted;
    state = state.copyWith(micMuted: muted);
    if (state.backendMode) {
      _client?.sendMicState(muted: muted);
      if (muted) {
        await _stopMic();
        await _voice.stopListening();
      } else if (state.mode == CompanionMode.backendLive) {
        await _startMicIfNeeded();
      } else {
        _armDeviceListening();
      }
    } else {
      if (muted) {
        await _voice.stopListening();
      } else {
        _nudges = 0;
        _lastInteraction = DateTime.now();
        _armDeviceListening();
      }
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final companionControllerProvider =
    StateNotifierProvider<CompanionController, CompanionState>((ref) {
  final controller = CompanionController(ref);
  ref.listen<VoiceState>(voiceControllerProvider, controller.onVoiceChanged);
  ref.listen<VisionState>(visionControllerProvider, controller.onVisionChanged);
  ref.listen(chatControllerProvider, controller.onChatChanged);
  return controller;
});
