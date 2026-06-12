import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import '../../models/avatar_emotion.dart';
import '../../providers/avatar_provider.dart';
import 'avatar_painter.dart';

/// Vyra's animated face — a glowing, emotive orb built entirely with Flutter's
/// own animation framework (a [Ticker] clock + [CustomPainter]); no Rive, no
/// Lottie, no asset files.
///
/// Prop-driven so it can be embedded anywhere (onboarding, chat, home hub).
/// For a version wired to global state, use [VyraAvatarLive].
class VyraAvatar extends StatefulWidget {
  const VyraAvatar({
    super.key,
    this.emotion = AvatarEmotion.neutral,
    this.activity = AvatarActivity.idle,
    this.amplitude = 0.0,
    this.size = 220,
  });

  final AvatarEmotion emotion;
  final AvatarActivity activity;
  final double amplitude;
  final double size;

  @override
  State<VyraAvatar> createState() => _VyraAvatarState();
}

class _VyraAvatarState extends State<VyraAvatar>
    with TickerProviderStateMixin {
  late final Ticker _clock;
  final ValueNotifier<double> _time = ValueNotifier(0);

  late final AnimationController _emotionCtrl;
  late final AnimationController _blinkCtrl;

  late FaceParams _from;
  late FaceParams _to;
  late AvatarEmotion _fromEmotion;
  late AvatarEmotion _toEmotion;

  double _amp = 0;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  static const double _breathPeriod = 4.0; // seconds
  static const double _ripplePeriod = 1.8;

  @override
  void initState() {
    super.initState();
    _from = FaceParams.forEmotion(widget.emotion.name);
    _to = _from;
    _fromEmotion = widget.emotion;
    _toEmotion = widget.emotion;

    _emotionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..value = 1.0;

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );

    _clock = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
      _amp += (widget.amplitude - _amp) * 0.18; // ease toward target
    })..start();

    _scheduleBlink();
  }

  void _scheduleBlink() {
    final ms = 2500 + _rng.nextInt(3800);
    _blinkTimer = Timer(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      await _blinkCtrl.forward(from: 0);
      await _blinkCtrl.reverse();
      _scheduleBlink();
    });
  }

  @override
  void didUpdateWidget(covariant VyraAvatar old) {
    super.didUpdateWidget(old);
    if (old.emotion != widget.emotion) {
      // Snapshot the current interpolated expression as the new "from".
      final t = Curves.easeInOut.transform(_emotionCtrl.value);
      _from = FaceParams.lerp(_from, _to, t);
      _to = FaceParams.forEmotion(widget.emotion.name);
      _fromEmotion = _toEmotion;
      _toEmotion = widget.emotion;
      _emotionCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _clock.dispose();
    _emotionCtrl.dispose();
    _blinkCtrl.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listenable =
        Listenable.merge([_time, _emotionCtrl, _blinkCtrl]);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_emotionCtrl.value);
          final face = FaceParams.lerp(_from, _to, t);
          final time = _time.value;
          // Blend emotion color through the transition too.
          final color =
              Color.lerp(_fromEmotion.color, _toEmotion.color, t)!;
          final accent =
              Color.lerp(_fromEmotion.accent, _toEmotion.accent, t)!;

          return CustomPaint(
            painter: AvatarPainter(
              face: face,
              color: color,
              accent: accent,
              breath: (time / _breathPeriod) % 1.0,
              blink: _blinkCtrl.value,
              ripple: (time / _ripplePeriod) % 1.0,
              amplitude: _amp.clamp(0.0, 1.0),
              activity: widget.activity,
              time: time,
            ),
          );
        },
      ),
    );
  }
}

/// [VyraAvatar] bound to the global [avatarControllerProvider] so chat, voice
/// and vision can all drive the same face.
class VyraAvatarLive extends ConsumerWidget {
  const VyraAvatarLive({super.key, this.size = 220});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(avatarControllerProvider);
    return VyraAvatar(
      emotion: state.emotion,
      activity: state.activity,
      amplitude: state.amplitude,
      size: size,
    );
  }
}
