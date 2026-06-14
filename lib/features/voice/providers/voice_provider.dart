import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/permission_service.dart';
import '../../../services/voice/stt_service.dart';
import '../../../services/voice/tts_service.dart';
import '../../avatar/providers/avatar_provider.dart';

final ttsServiceProvider = Provider<TtsService>((ref) => TtsService.instance);
final sttServiceProvider = Provider<SttService>((ref) => SttService.instance);

@immutable
class VoiceState {
  final bool sttAvailable;
  final bool isListening;
  final bool isSpeaking;
  final String partialText;

  const VoiceState({
    this.sttAvailable = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.partialText = '',
  });

  VoiceState copyWith({
    bool? sttAvailable,
    bool? isListening,
    bool? isSpeaking,
    String? partialText,
  }) =>
      VoiceState(
        sttAvailable: sttAvailable ?? this.sttAvailable,
        isListening: isListening ?? this.isListening,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        partialText: partialText ?? this.partialText,
      );
}

/// The bridge between Vyra's ears (STT), her voice (TTS) and her face: while
/// listening it feeds mic levels to the avatar; while speaking it pulses the
/// mouth (flutter_tts gives no audio levels, so we simulate a natural cadence).
class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._ref) : super(const VoiceState()) {
    _init();
  }

  final Ref _ref;
  void Function(String)? _onFinal;
  String _heard = ''; // latest recognized text this session
  bool _delivered = true; // whether _heard was already sent (or discarded)
  Timer? _speakPulse;
  final math.Random _rng = math.Random();

  TtsService get _tts => _ref.read(ttsServiceProvider);
  SttService get _stt => _ref.read(sttServiceProvider);
  AvatarController get _avatar => _ref.read(avatarControllerProvider.notifier);

  Future<void> _init() async {
    await _tts.init(
      onStart: _onSpeakStart,
      onComplete: _onSpeakComplete,
      rate: _ref.read(settingsProvider).speechRate,
    );
    // Ask for the microphone through the shared queue so it never races the
    // weather feature's location request — concurrent dialogs dropped one
    // another (mic wasn't asked on first launch) and left the loser's Future
    // hanging. With mic already granted, speech_to_text won't prompt again.
    await PermissionService.instance.request(Permission.microphone);
    final available = await _stt.init(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _endSession();
      },
      onError: (_) => _endSession(),
    );
    state = state.copyWith(sttAvailable: available);
  }

  // --- Listening ---
  Future<void> toggleListen({required void Function(String) onFinal}) async {
    if (state.isListening) {
      await stopListening();
    } else {
      await startListening(onFinal: onFinal);
    }
  }

  Future<void> startListening({required void Function(String) onFinal}) async {
    if (!state.sttAvailable || state.isListening) return;
    await _tts.stop();
    _onFinal = onFinal;
    _heard = '';
    _delivered = false;
    state = state.copyWith(isListening: true, partialText: '');
    _avatar.setActivity(AvatarActivity.listening);
    await _stt.listen(
      onPartial: (txt) {
        _heard = txt;
        state = state.copyWith(partialText: txt);
      },
      onFinal: (txt) {
        if (txt.trim().isNotEmpty) _heard = txt;
        _deliverHeard();
        _finishListening();
      },
      onLevel: (level) =>
          _avatar.setAmplitude((level.abs() / 10).clamp(0.05, 1.0).toDouble()),
    );
  }

  Future<void> stopListening() async {
    // Explicit stop (mute, or before speaking): discard any in-progress partial.
    _delivered = true;
    await _stt.stop();
    _finishListening();
  }

  void _finishListening() {
    if (!state.isListening) return;
    state = state.copyWith(isListening: false, partialText: '');
    _avatar.idle();
  }

  // If a listen session ends without a FINAL result (common on Android), still
  // deliver the last recognized partial so the user's speech is never dropped.
  void _endSession() {
    _deliverHeard();
    _finishListening();
  }

  void _deliverHeard() {
    if (_delivered) return;
    _delivered = true;
    final text = _heard.trim();
    if (text.isNotEmpty) _onFinal?.call(text);
  }

  // --- Speaking ---
  Future<void> speak(String text) async {
    if (!_ref.read(settingsProvider).ttsEnabled) return;
    // Stop the mic before talking so she never hears herself (key for the
    // hands-free / always-listening mode).
    if (state.isListening) await stopListening();
    await _tts.setRate(_ref.read(settingsProvider).speechRate);
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _onSpeakComplete();
  }

  void _onSpeakStart() {
    state = state.copyWith(isSpeaking: true);
    _avatar.setActivity(AvatarActivity.speaking);
    _speakPulse?.cancel();
    _speakPulse = Timer.periodic(const Duration(milliseconds: 120), (_) {
      _avatar.setAmplitude(0.3 + _rng.nextDouble() * 0.6);
    });
  }

  void _onSpeakComplete() {
    _speakPulse?.cancel();
    _speakPulse = null;
    if (mounted) state = state.copyWith(isSpeaking: false);
    _avatar.idle();
  }

  @override
  void dispose() {
    _speakPulse?.cancel();
    super.dispose();
  }
}

final voiceControllerProvider =
    StateNotifierProvider<VoiceController, VoiceState>(
  (ref) => VoiceController(ref),
);
