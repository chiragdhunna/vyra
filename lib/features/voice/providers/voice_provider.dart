import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/settings_provider.dart';
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
    final available = await _stt.init(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _finishListening();
      },
      onError: (_) => _finishListening(),
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
    state = state.copyWith(isListening: true, partialText: '');
    _avatar.setActivity(AvatarActivity.listening);
    await _stt.listen(
      onPartial: (txt) => state = state.copyWith(partialText: txt),
      onFinal: (txt) {
        final trimmed = txt.trim();
        _finishListening();
        if (trimmed.isNotEmpty) _onFinal?.call(trimmed);
      },
      onLevel: (level) =>
          _avatar.setAmplitude((level.abs() / 10).clamp(0.05, 1.0).toDouble()),
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _finishListening();
  }

  void _finishListening() {
    if (!state.isListening) return;
    state = state.copyWith(isListening: false, partialText: '');
    _avatar.idle();
  }

  // --- Speaking ---
  Future<void> speak(String text) async {
    if (!_ref.read(settingsProvider).ttsEnabled) return;
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
