import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A row of softly pulsing bars that visualize live audio level. Purely
/// hand-animated (an [AnimationController] + [CustomPainter]) — no packages.
class VoiceWave extends StatefulWidget {
  const VoiceWave({
    super.key,
    required this.amplitude,
    required this.color,
    this.bars = 24,
    this.height = 40,
  });

  final double amplitude; // 0..1
  final Color color;
  final int bars;
  final double height;

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WavePainter(
            t: _c.value,
            amplitude: widget.amplitude,
            color: widget.color,
            bars: widget.bars,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.t,
    required this.amplitude,
    required this.color,
    required this.bars,
  });

  final double t;
  final double amplitude;
  final Color color;
  final int bars;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.width / bars) * 0.45;

    final gap = size.width / bars;
    final mid = size.height / 2;
    final amp = 0.25 + amplitude * 0.75;

    for (var i = 0; i < bars; i++) {
      final phase = t * 2 * math.pi + i * 0.5;
      final wave = (math.sin(phase) * 0.5 + 0.5);
      final h = (size.height * 0.12) +
          (size.height * 0.78) * wave * amp;
      final x = gap * (i + 0.5);
      paint.color = color.withValues(alpha: 0.4 + 0.6 * wave);
      canvas.drawLine(
        Offset(x, mid - h / 2),
        Offset(x, mid + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}
