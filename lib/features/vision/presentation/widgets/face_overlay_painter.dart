import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/theme/app_colors.dart';

/// Draws rounded boxes around detected faces, mapping ML Kit's image-space
/// coordinates onto the preview using the standard ML Kit translator (handles
/// rotation + front-camera mirroring). Alignment is best-effort across exotic
/// orientations but accurate for the common portrait selfie case.
class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter({
    required this.faceRects,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final List<Rect> faceRects;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == Size.zero || faceRects.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.accent;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = AppColors.accent.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final rect in faceRects) {
      final l = _tx(rect.left, size);
      final r = _tx(rect.right, size);
      final t = _ty(rect.top, size);
      final b = _ty(rect.bottom, size);
      final mapped = Rect.fromLTRB(
        math.min(l, r),
        math.min(t, b),
        math.max(l, r),
        math.max(t, b),
      );
      final rr = RRect.fromRectAndRadius(mapped, const Radius.circular(16));
      canvas.drawRRect(rr, glow);
      canvas.drawRRect(rr, paint);
    }
  }

  double _tx(double x, Size canvas) =>
      _translateX(x, canvas, imageSize, rotation, lensDirection);
  double _ty(double y, Size canvas) =>
      _translateY(y, canvas, imageSize, rotation, lensDirection);

  @override
  bool shouldRepaint(covariant FaceOverlayPainter old) =>
      old.faceRects != faceRects || old.imageSize != imageSize;
}

double _translateX(
  double x,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection lens,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x *
          canvasSize.width /
          (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation270deg:
      return canvasSize.width -
          x *
              canvasSize.width /
              (Platform.isIOS ? imageSize.width : imageSize.height);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      switch (lens) {
        case CameraLensDirection.back:
          return x * canvasSize.width / imageSize.width;
        default:
          return canvasSize.width - x * canvasSize.width / imageSize.width;
      }
  }
}

double _translateY(
  double y,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection lens,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          canvasSize.height /
          (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvasSize.height / imageSize.height;
  }
}
