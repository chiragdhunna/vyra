import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../providers/avatar_provider.dart';

/// Numeric description of a facial expression. Every emotion maps to one of
/// these, and the painter renders the smoothly interpolated value between the
/// previous and current emotion (see [FaceParams.lerp]).
@immutable
class FaceParams {
  final double eyeOpen; // 0..1.3 vertical eye extent
  final double eyeSmile; // 0..1 weight of "smiling eyes" crescent
  final double browTilt; // -1 focused (inner down) .. +1 worried (inner up)
  final double browRaise; // 0..1 raise both brows (surprise / excitement)
  final double mouthCurve; // -1 frown .. +1 smile
  final double mouthOpen; // 0..1 vertical mouth opening
  final double mouthWidth; // 0..1 mouth width
  final double pupilY; // -1 look up .. +1 look down
  final double glow; // 0.6..1.3 aura intensity
  final double tears; // 0..1 crying-tears intensity

  const FaceParams({
    required this.eyeOpen,
    required this.eyeSmile,
    required this.browTilt,
    required this.browRaise,
    required this.mouthCurve,
    required this.mouthOpen,
    required this.mouthWidth,
    required this.pupilY,
    required this.glow,
    this.tears = 0.0,
  });

  static double _l(double a, double b, double t) => a + (b - a) * t;

  static FaceParams lerp(FaceParams a, FaceParams b, double t) => FaceParams(
        eyeOpen: _l(a.eyeOpen, b.eyeOpen, t),
        eyeSmile: _l(a.eyeSmile, b.eyeSmile, t),
        browTilt: _l(a.browTilt, b.browTilt, t),
        browRaise: _l(a.browRaise, b.browRaise, t),
        mouthCurve: _l(a.mouthCurve, b.mouthCurve, t),
        mouthOpen: _l(a.mouthOpen, b.mouthOpen, t),
        mouthWidth: _l(a.mouthWidth, b.mouthWidth, t),
        pupilY: _l(a.pupilY, b.pupilY, t),
        glow: _l(a.glow, b.glow, t),
        tears: _l(a.tears, b.tears, t),
      );

  static const Map<String, FaceParams> _byEmotion = {
    'neutral': FaceParams(
        eyeOpen: 1.0, eyeSmile: 0.0, browTilt: 0.0, browRaise: 0.15,
        mouthCurve: 0.2, mouthOpen: 0.05, mouthWidth: 0.55, pupilY: 0.0, glow: 0.9),
    'happy': FaceParams(
        eyeOpen: 0.9, eyeSmile: 0.7, browTilt: 0.0, browRaise: 0.2,
        mouthCurve: 0.9, mouthOpen: 0.2, mouthWidth: 0.8, pupilY: 0.0, glow: 1.05),
    'excited': FaceParams(
        eyeOpen: 1.1, eyeSmile: 0.3, browTilt: 0.0, browRaise: 0.6,
        mouthCurve: 1.0, mouthOpen: 0.55, mouthWidth: 0.9, pupilY: -0.05, glow: 1.25),
    'thinking': FaceParams(
        eyeOpen: 0.85, eyeSmile: 0.0, browTilt: -0.3, browRaise: 0.1,
        mouthCurve: -0.05, mouthOpen: 0.0, mouthWidth: 0.4, pupilY: -0.45, glow: 0.85),
    'sad': FaceParams(
        eyeOpen: 0.7, eyeSmile: 0.0, browTilt: 0.7, browRaise: 0.0,
        mouthCurve: -0.7, mouthOpen: 0.0, mouthWidth: 0.5, pupilY: 0.3, glow: 0.7),
    'surprised': FaceParams(
        eyeOpen: 1.25, eyeSmile: 0.0, browTilt: 0.0, browRaise: 0.8,
        mouthCurve: 0.0, mouthOpen: 0.85, mouthWidth: 0.45, pupilY: 0.0, glow: 1.1),
    'caring': FaceParams(
        eyeOpen: 0.85, eyeSmile: 0.5, browTilt: 0.2, browRaise: 0.1,
        mouthCurve: 0.6, mouthOpen: 0.1, mouthWidth: 0.7, pupilY: 0.05, glow: 1.0),
    'cry': FaceParams(
        eyeOpen: 0.55, eyeSmile: 0.0, browTilt: 0.95, browRaise: 0.0,
        mouthCurve: -0.8, mouthOpen: 0.45, mouthWidth: 0.55, pupilY: 0.35,
        glow: 0.6, tears: 1.0),
  };

  static FaceParams forEmotion(String name) =>
      _byEmotion[name] ?? _byEmotion['neutral']!;
}

/// Paints Vyra's animated face. Stateless w.r.t. animation — all motion is fed
/// in via the constructor and recomputed every frame by an [AnimatedBuilder].
class AvatarPainter extends CustomPainter {
  AvatarPainter({
    required this.face,
    required this.color,
    required this.accent,
    required this.breath,
    required this.blink,
    required this.ripple,
    required this.amplitude,
    required this.activity,
    required this.time,
  });

  final FaceParams face;
  final Color color;
  final Color accent;
  final double breath; // 0..1 breathing phase
  final double blink; // 0 open .. 1 closed
  final double ripple; // 0..1 ring expansion phase
  final double amplitude; // 0..1 voice level
  final AvatarActivity activity;
  final double time; // continuous seconds, for particles & thinking dots

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave headroom for the aura + rings.
    final r = math.min(size.width, size.height) / 2 * 0.62;
    final breathScale = 1.0 + math.sin(breath * 2 * math.pi) * 0.025;

    _drawAura(canvas, center, r, breathScale);
    if (activity == AvatarActivity.speaking ||
        activity == AvatarActivity.listening) {
      _drawRipples(canvas, center, r);
    }
    _drawParticles(canvas, center, r);
    _drawOrb(canvas, center, r * breathScale);
    _drawFace(canvas, center, r * breathScale);
    if (activity == AvatarActivity.thinking) {
      _drawThinkingDots(canvas, center, r);
    }
  }

  // --- Aura / outer glow ---
  void _drawAura(Canvas canvas, Offset center, double r, double breathScale) {
    final glow = face.glow * (0.9 + amplitude * 0.3);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.28 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55);
    canvas.drawCircle(center, r * 1.18 * breathScale, paint);

    final inner = Paint()
      ..color = accent.withValues(alpha: 0.18 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35);
    canvas.drawCircle(center, r * 0.95 * breathScale, inner);
  }

  // --- Sound-wave ripples while speaking / listening ---
  void _drawRipples(Canvas canvas, Offset center, double r) {
    final ringColor = activity == AvatarActivity.listening ? accent : color;
    const count = 3;
    for (var i = 0; i < count; i++) {
      final t = (ripple + i / count) % 1.0;
      final radius = r * (1.0 + t * (0.55 + amplitude * 0.5));
      final opacity = (1 - t) * (0.18 + amplitude * 0.35);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = ringColor.withValues(alpha: opacity.clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(center, radius, paint);
    }
  }

  // --- Ambient twinkling particles orbiting the orb ---
  void _drawParticles(Canvas canvas, Offset center, double r) {
    const count = 12;
    for (var i = 0; i < count; i++) {
      // Deterministic pseudo-random layout per particle index.
      final seed = i * 12.9898;
      final baseAngle = (math.sin(seed) * 0.5 + 0.5) * 2 * math.pi;
      final orbitR = r * (1.25 + (math.cos(seed * 1.7) * 0.5 + 0.5) * 0.45);
      final speed = 0.15 + (math.sin(seed * 2.3) * 0.5 + 0.5) * 0.25;
      final angle = baseAngle + time * speed;
      final twinkle =
          (math.sin(time * 2 + i * 1.7) * 0.5 + 0.5); // 0..1
      final pos = center +
          Offset(math.cos(angle), math.sin(angle)) * orbitR;
      final dotR = r * (0.012 + 0.02 * twinkle);
      final paint = Paint()
        ..color = (i.isEven ? accent : color)
            .withValues(alpha: 0.25 + 0.4 * twinkle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.02);
      canvas.drawCircle(pos, dotR, paint);
    }
  }

  // --- Orb body ---
  void _drawOrb(Canvas canvas, Offset center, double r) {
    final rect = Rect.fromCircle(center: center, radius: r);
    final gradient = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 1.05,
      colors: [
        Color.lerp(accent, Colors.white, 0.35)!,
        color,
        _shade(color, -0.4),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final body = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(center, r, body);

    // Rim light.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..color = Color.lerp(accent, Colors.white, 0.4)!.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
    canvas.drawCircle(center, r * 0.98, rim);

    // Specular highlight.
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08);
    canvas.drawCircle(
      center + Offset(-r * 0.32, -r * 0.4),
      r * 0.16,
      highlight,
    );
  }

  // --- Face: brows, eyes, mouth ---
  void _drawFace(Canvas canvas, Offset center, double r) {
    final eyeDX = r * 0.36;
    final eyeY = center.dy - r * 0.08;
    final leftEye = Offset(center.dx - eyeDX, eyeY);
    final rightEye = Offset(center.dx + eyeDX, eyeY);

    final dark = _shade(color, -0.72);

    _drawBrow(canvas, leftEye, r, dark, isLeft: true);
    _drawBrow(canvas, rightEye, r, dark, isLeft: false);
    _drawEye(canvas, leftEye, r, dark);
    _drawEye(canvas, rightEye, r, dark);
    _drawMouth(canvas, center, r, dark);
    if (face.tears > 0.01) {
      _drawTear(canvas, leftEye, r, seed: 0.0);
      _drawTear(canvas, rightEye, r, seed: 0.5);
    }
  }

  // Falling tear-drops for the "cry" emotion (two staggered drops per eye).
  void _drawTear(Canvas canvas, Offset eye, double r, {required double seed}) {
    final ew = r * 0.15;
    for (var i = 0; i < 2; i++) {
      final phase = (time * 0.5 + seed + i * 0.5) % 1.0;
      final x = eye.dx + ew * 0.1;
      final y = eye.dy + ew * 0.6 + phase * r * 0.55;
      final alpha = (face.tears * (1 - phase)).clamp(0.0, 1.0).toDouble();
      if (alpha <= 0.02) continue;
      final paint = Paint()
        ..color = const Color(0xFFB8DCFF).withValues(alpha: alpha);
      final rr = r * 0.035;
      canvas.drawCircle(Offset(x, y), rr, paint);
      final tip = Path()
        ..moveTo(x - rr * 0.55, y)
        ..lineTo(x, y - rr * 1.9)
        ..lineTo(x + rr * 0.55, y)
        ..close();
      canvas.drawPath(tip, paint);
      canvas.drawCircle(
        Offset(x - rr * 0.3, y - rr * 0.3),
        rr * 0.3,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.7),
      );
    }
  }

  void _drawEye(Canvas canvas, Offset c, double r, Color dark) {
    final ew = r * 0.15;
    final openness = (face.eyeOpen * (1 - blink)).clamp(0.04, 1.4).toDouble();
    final eh = r * 0.30 * openness;

    // Open-eye capsule (crossfaded against the smiling crescent).
    final openWeight = (1 - face.eyeSmile).clamp(0.0, 1.0).toDouble();
    if (openWeight > 0.01) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: ew * 2, height: eh * 2),
        Radius.circular(ew),
      );
      final paint = Paint()..color = dark.withValues(alpha: openWeight);
      canvas.drawRRect(rrect, paint);

      // Pupil + catchlight when the eye is meaningfully open.
      if (openness > 0.35) {
        final look = Offset(0, face.pupilY * eh * 0.4);
        final glassPaint = Paint()
          ..color = Color.lerp(accent, Colors.white, 0.6)!
              .withValues(alpha: 0.85 * openWeight);
        canvas.drawCircle(c + look + Offset(-ew * 0.25, -eh * 0.25),
            ew * 0.32, glassPaint);
      }
    }

    // Smiling-eyes crescent (∩).
    if (face.eyeSmile > 0.01) {
      final path = Path()
        ..moveTo(c.dx - ew, c.dy + eh * 0.1)
        ..quadraticBezierTo(
            c.dx, c.dy - eh * 0.9, c.dx + ew, c.dy + eh * 0.1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.045
        ..strokeCap = StrokeCap.round
        ..color = dark.withValues(alpha: face.eyeSmile);
      canvas.drawPath(path, paint);
    }
  }

  void _drawBrow(Canvas canvas, Offset eye, double r, Color dark,
      {required bool isLeft}) {
    final alpha = (face.browRaise * 0.55 + face.browTilt.abs() * 0.7)
        .clamp(0.0, 0.85)
        .toDouble();
    if (alpha < 0.05) return;

    final browY = eye.dy - r * 0.27 - face.browRaise * r * 0.06;
    final half = r * 0.16;
    final dir = isLeft ? 1.0 : -1.0; // inner side direction
    final inner = Offset(eye.dx + dir * half * 0.6,
        browY - face.browTilt * r * 0.05);
    final outer = Offset(eye.dx - dir * half * 0.9,
        browY + face.browTilt * r * 0.03);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..strokeCap = StrokeCap.round
      ..color = dark.withValues(alpha: alpha);
    canvas.drawLine(inner, outer, paint);
  }

  void _drawMouth(Canvas canvas, Offset center, double r, Color dark) {
    final my = center.dy + r * 0.42;
    final mw = r * (0.16 + 0.26 * face.mouthWidth);

    // Live talking motion adds to the opening while speaking.
    final speakBoost =
        activity == AvatarActivity.speaking ? amplitude * 0.45 : 0.0;
    final open = (face.mouthOpen + speakBoost).clamp(0.0, 1.2).toDouble() * r * 0.32;

    final lineWeight = (1 - face.mouthOpen).clamp(0.0, 1.0).toDouble();

    // Smile / frown line.
    if (lineWeight > 0.02) {
      final path = Path()
        ..moveTo(center.dx - mw, my - face.mouthCurve * r * 0.04)
        ..quadraticBezierTo(
          center.dx,
          my + face.mouthCurve * r * 0.24,
          center.dx + mw,
          my - face.mouthCurve * r * 0.04,
        );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round
        ..color = dark.withValues(alpha: lineWeight);
      canvas.drawPath(path, paint);
    }

    // Open mouth (talking / surprise).
    if (open > r * 0.02) {
      final rect = Rect.fromCenter(
        center: Offset(center.dx, my),
        width: mw * 1.3,
        height: open * 1.6,
      );
      final fill = Paint()..color = dark.withValues(alpha: 0.92);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(open)),
        fill,
      );
      // Soft inner tongue glow for warmth.
      final tongue = Paint()
        ..color = accent.withValues(alpha: 0.25);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(center.dx, my + open * 0.4),
              width: mw * 0.9,
              height: open * 0.7),
          Radius.circular(open),
        ),
        tongue,
      );
    }
  }

  // --- "Thinking…" orbiting dots above the orb ---
  void _drawThinkingDots(Canvas canvas, Offset center, double r) {
    final baseY = center.dy - r * 1.35;
    for (var i = 0; i < 3; i++) {
      final phase = (time * 1.6 - i * 0.25) % 1.0;
      final lift = math.sin(phase * math.pi); // 0..1..0
      final pos = Offset(
        center.dx + (i - 1) * r * 0.22,
        baseY - lift * r * 0.12,
      );
      final paint = Paint()
        ..color = accent.withValues(alpha: 0.5 + 0.5 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.015);
      canvas.drawCircle(pos, r * 0.05, paint);
    }
  }

  /// Lightens (positive) or darkens (negative) a color in HSL space.
  Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final l = (hsl.lightness + amount).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(l).toColor();
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => true;
}
