import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/anime_sprites.dart';
import '../../providers/avatar_provider.dart';
import 'vyra_avatar.dart';

/// Vyra as a living anime character.
///
/// A sprite-driven ("PNGtuber"-style) avatar: 9 emotions x 3 frames
/// (idle / talking / blink) of one consistent hand-off character, embedded
/// in the binary and composited with life-like motion:
///
///  * **lip flap** — while speaking, the mouth frame follows the voice
///    amplitude published by the voice layer, so her lips move with her voice
///  * **blinking** — randomized natural blinks (120 ms, every 2.5–5.5 s)
///  * **breathing** — a slow, subtle scale/translate sine so she never
///    freezes, plus a gentle sway
///  * **emotion crossfades** — `[emotion: X]` tags drive soft 240 ms
///    transitions between expression sets
///  * **presence glow** — an ambient aura behind her that warms while she
///    listens and pulses with the sound level
///
/// Frame swaps inside one emotion (idle→talk→blink) are instant and
/// flicker-free (`gaplessPlayback`); if sprite data ever fails to decode the
/// widget falls back to the classic orb ([VyraAvatarLive]).
class AnimeAvatar extends ConsumerStatefulWidget {
  const AnimeAvatar({super.key, this.width = 300});

  final double width;

  @override
  ConsumerState<AnimeAvatar> createState() => _AnimeAvatarState();
}

class _AnimeAvatarState extends ConsumerState<AnimeAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life; // continuous clock for breath/sway
  final math.Random _rng = math.Random();

  Timer? _blinkTimer;
  bool _blinking = false;
  bool _mouthOpen = false;
  DateTime _lastMouthFlip = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    // Decode all frames up-front so expression changes never hitch.
    WidgetsBinding.instance.addPostFrameCallback((_) => AnimeSprites.warmUp());
    _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _life.dispose();
    super.dispose();
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 2500 + _rng.nextInt(3000)),
      () async {
        if (!mounted) return;
        setState(() => _blinking = true);
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      },
    );
  }

  /// Mouth follows voice amplitude with a small hold time so the flap reads
  /// as syllables instead of flicker.
  bool _mouthFor(AvatarState avatar) {
    if (avatar.activity != AvatarActivity.speaking) {
      if (_mouthOpen) _mouthOpen = false;
      return false;
    }
    final now = DateTime.now();
    if (now.difference(_lastMouthFlip) >= const Duration(milliseconds: 90)) {
      final open = avatar.amplitude > 0.45;
      if (open != _mouthOpen) {
        _mouthOpen = open;
        _lastMouthFlip = now;
      }
    }
    return _mouthOpen;
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(avatarControllerProvider);
    final emotion = avatar.emotion.name;
    final mouthOpen = _mouthFor(avatar);

    final String state;
    if (_blinking) {
      state = 'blink';
    } else if (mouthOpen) {
      state = 'talk';
    } else {
      state = 'idle';
    }

    final width = widget.width;
    final height = width * 1.5; // sprites are 2:3
    final glow = avatar.emotion.color;
    final listening = avatar.activity == AvatarActivity.listening;
    final speaking = avatar.activity == AvatarActivity.speaking;

    return AnimatedBuilder(
      animation: _life,
      builder: (context, child) {
        final t = _life.value * 2 * math.pi;
        final breathe = math.sin(t * 2); // ~2 breaths per cycle
        final sway = math.sin(t) * 0.008; // radians, very subtle
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ambient presence glow behind her.
            Container(
              width: width * 0.92,
              height: height * 0.92,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.12),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(
                      alpha: (0.30 +
                              (listening ? 0.12 : 0.0) +
                              (speaking ? avatar.amplitude * 0.25 : 0.0))
                          .clamp(0.0, 0.6)
                          .toDouble(),
                    ),
                    blurRadius: width * 0.22 + breathe * 4,
                    spreadRadius: 2 + (speaking ? avatar.amplitude * 8 : 0),
                  ),
                ],
              ),
            ),
            Transform.rotate(
              angle: sway,
              child: Transform.translate(
                offset: Offset(0, breathe * 2.5),
                child: Transform.scale(
                  scale: 1.0 + breathe * 0.006,
                  child: child,
                ),
              ),
            ),
            if (avatar.activity == AvatarActivity.thinking)
              Positioned(
                top: -6,
                child: _ThinkingDots(color: avatar.emotion.accent),
              ),
          ],
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.11),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: glow.withValues(alpha: 0.35),
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(width * 0.11),
          ),
          // Soft crossfade between EMOTIONS; instant gapless swap between
          // frames (idle/talk/blink) inside one emotion.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: KeyedSubtree(
              key: ValueKey<String>(emotion),
              child: Image.memory(
                AnimeSprites.bytesFor(emotion, state),
                width: width,
                height: height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    const VyraAvatarLive(size: 260),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.color});
  final Color color;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.18) % 1.0;
            final lift = math.sin(phase * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -6.0 * lift),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color
                        .withValues(alpha: 0.35 + 0.65 * lift),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4 * lift),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
