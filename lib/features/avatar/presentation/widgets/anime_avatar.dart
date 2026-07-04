import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/anime_sprites.dart';
import '../../providers/avatar_provider.dart';
import 'vyra_avatar.dart';

/// Vyra as a living anime character — frameless: just her.
///
/// The sprites share one flat background color ([AnimeSprites.background]);
/// the screen paints that exact color, so no card, border or edge is ever
/// visible — only the girl, alive on the screen:
///
///  * **lip flap** synced to her voice amplitude
///  * **blinking**, **breathing**, subtle sway — she never freezes
///  * **gestures** — wave (greetings), laugh, sleepy stretch, curious lean;
///    driven by the backend or played as idle fidgets so she "does things"
///  * **emotion entrances** — anger shakes, excitement pops, sadness droops,
///    surprise hops; then the expression settles
///  * **listening lean-in** — she scales up a touch while you talk;
///    speaking adds a gentle head bob with her voice
class AnimeAvatar extends ConsumerStatefulWidget {
  const AnimeAvatar({super.key, this.width = 300});

  final double width;

  @override
  ConsumerState<AnimeAvatar> createState() => _AnimeAvatarState();
}

class _AnimeAvatarState extends ConsumerState<AnimeAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _life; // continuous clock (breath/sway/bob)
  late final AnimationController _entry; // one-shot emotion entrance
  final math.Random _rng = math.Random();

  Timer? _blinkTimer;
  Timer? _fidgetTimer;
  bool _blinking = false;
  bool _mouthOpen = false;
  DateTime _lastMouthFlip = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastEmotion = 'neutral';
  String _entryEffect = '';

  @override
  void initState() {
    super.initState();
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => AnimeSprites.warmUp());
    _scheduleBlink();
    _scheduleFidget();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _fidgetTimer?.cancel();
    _life.dispose();
    _entry.dispose();
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

  /// Idle fidgets: every so often she leans in curiously or stretches —
  /// a person sitting there, not a poster.
  void _scheduleFidget() {
    _fidgetTimer?.cancel();
    _fidgetTimer = Timer(
      Duration(seconds: 24 + _rng.nextInt(26)),
      () {
        if (!mounted) return;
        final avatar = ref.read(avatarControllerProvider);
        final calm = avatar.activity == AvatarActivity.idle ||
            avatar.activity == AvatarActivity.listening;
        if (calm && avatar.gesture == null && avatar.amplitude < 0.15) {
          ref.read(avatarControllerProvider.notifier).playGesture(
                _rng.nextBool() ? 'lean' : 'stretch',
                duration: const Duration(milliseconds: 2200),
              );
        }
        _scheduleFidget();
      },
    );
  }

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

  void _maybeTriggerEntrance(String emotion) {
    if (emotion == _lastEmotion) return;
    _lastEmotion = emotion;
    _entryEffect = switch (emotion) {
      'angry' => 'shake',
      'excited' => 'pop',
      'surprised' => 'hop',
      'sad' || 'cry' => 'droop',
      'happy' => 'pop_soft',
      _ => '',
    };
    if (_entryEffect.isNotEmpty) {
      _entry.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ref.watch(avatarControllerProvider);
    final emotion = avatar.emotion.name;
    _maybeTriggerEntrance(emotion);
    final mouthOpen = _mouthFor(avatar);

    // Frame selection: gesture pose > blink > talk > idle.
    final gesture = avatar.gesture;
    final bool usingGesture =
        gesture != null && AnimeSprites.hasGesture(gesture);
    final bytes = usingGesture
        ? AnimeSprites.gestureBytesFor(gesture, talking: mouthOpen)!
        : AnimeSprites.bytesFor(
            emotion,
            _blinking
                ? 'blink'
                : mouthOpen
                    ? 'talk'
                    : 'idle',
          );

    final width = widget.width;
    final height = width * 1.5; // sprites are 2:3
    final listening = avatar.activity == AvatarActivity.listening;
    final speaking = avatar.activity == AvatarActivity.speaking;

    return AnimatedBuilder(
      animation: Listenable.merge([_life, _entry]),
      builder: (context, child) {
        final t = _life.value * 2 * math.pi;
        final breathe = math.sin(t * 2);
        var dx = 0.0;
        var dy = breathe * 2.5;
        var angle = math.sin(t) * 0.008;
        var scale = 1.0 + breathe * 0.006;

        // She leans in a touch while listening; bobs gently as she talks.
        if (listening) scale += 0.015;
        if (speaking) {
          dy += math.sin(t * 6) * avatar.amplitude * 2.2;
          angle += math.sin(t * 3) * 0.004 * avatar.amplitude;
        }

        // One-shot emotion entrances.
        if (_entry.isAnimating) {
          final e = _entry.value; // 0..1
          final fade = 1 - e;
          switch (_entryEffect) {
            case 'shake':
              dx += math.sin(e * math.pi * 7) * 7 * fade;
            case 'pop':
              scale += math.sin(e * math.pi) * 0.055;
            case 'pop_soft':
              scale += math.sin(e * math.pi) * 0.03;
            case 'hop':
              dy -= math.sin(e * math.pi) * 12;
            case 'droop':
              dy += math.sin(e * math.pi / 2) * 6;
              angle += math.sin(e * math.pi / 2) * 0.012;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
            if (avatar.activity == AvatarActivity.thinking)
              Positioned(
                top: height * 0.02,
                child: _ThinkingDots(color: avatar.emotion.accent),
              ),
          ],
        );
      },
      // No card, no border, no glow: the sprite background matches the
      // screen background exactly, so only she is visible.
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: KeyedSubtree(
            key: ValueKey<String>(usingGesture ? 'g:$gesture' : emotion),
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const VyraAvatarLive(size: 260),
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
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
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
                    color: widget.color.withValues(alpha: 0.35 + 0.65 * lift),
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
