import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/avatar_emotion.dart';

/// What Vyra is currently *doing* — drives motion layered on top of [AvatarEmotion]:
/// idle breathing, listening pulse, thinking wobble, or speaking sound-rings.
enum AvatarActivity { idle, listening, thinking, speaking }

@immutable
class AvatarState {
  final AvatarEmotion emotion;
  final AvatarActivity activity;

  /// 0..1 audio level, used to size the speaking/listening ripple rings.
  final double amplitude;

  const AvatarState({
    this.emotion = AvatarEmotion.neutral,
    this.activity = AvatarActivity.idle,
    this.amplitude = 0.0,
  });

  AvatarState copyWith({
    AvatarEmotion? emotion,
    AvatarActivity? activity,
    double? amplitude,
  }) {
    return AvatarState(
      emotion: emotion ?? this.emotion,
      activity: activity ?? this.activity,
      amplitude: amplitude ?? this.amplitude,
    );
  }
}

/// Single source of truth for the avatar's mood and motion. Chat, voice and
/// vision features all push updates here so the face reacts in sync.
class AvatarController extends StateNotifier<AvatarState> {
  AvatarController() : super(const AvatarState());

  void setEmotion(AvatarEmotion emotion) =>
      state = state.copyWith(emotion: emotion);

  void setActivity(AvatarActivity activity) =>
      state = state.copyWith(activity: activity);

  void setAmplitude(double amplitude) =>
      state = state.copyWith(amplitude: amplitude.clamp(0.0, 1.0).toDouble());

  /// Convenience: react with an emotion (and optionally an activity) at once.
  void react(AvatarEmotion emotion, {AvatarActivity? activity}) {
    state = state.copyWith(
      emotion: emotion,
      activity: activity ?? state.activity,
    );
  }

  void idle() =>
      state = state.copyWith(activity: AvatarActivity.idle, amplitude: 0.0);
}

final avatarControllerProvider =
    StateNotifierProvider<AvatarController, AvatarState>(
  (ref) => AvatarController(),
);
