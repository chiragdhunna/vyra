import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Turns one [CameraImage] into a small JPEG for the backend's vision LLM.
///
/// The glimpse only needs the gist of the scene, so frames are aggressively
/// downscaled (~[targetWidth] px) — a few tens of KB every ~20 s, nothing
/// like a video stream. Supports Android NV21 and iOS BGRA8888.
Uint8List? encodeCameraFrame(CameraImage image, {int targetWidth = 320}) {
  try {
    final img.Image? rgb = switch (image.format.group) {
      ImageFormatGroup.nv21 => _nv21ToImage(image, targetWidth),
      ImageFormatGroup.bgra8888 => _bgraToImage(image, targetWidth),
      _ => null,
    };
    if (rgb == null) return null;
    return Uint8List.fromList(img.encodeJpg(rgb, quality: 60));
  } catch (_) {
    return null;
  }
}

img.Image _nv21ToImage(CameraImage image, int targetWidth) {
  final width = image.width;
  final height = image.height;
  final bytes = image.planes.first.bytes;
  final rowStride = image.planes.first.bytesPerRow;
  final step = (width / targetWidth).ceil().clamp(1, 16);

  final outW = (width / step).floor();
  final outH = (height / step).floor();
  final out = img.Image(width: outW, height: outH);
  final uvStart = rowStride * height;

  for (var oy = 0; oy < outH; oy++) {
    final y = oy * step;
    for (var ox = 0; ox < outW; ox++) {
      final x = ox * step;
      final yValue = bytes[y * rowStride + x];
      // NV21: interleaved VU pairs at quarter resolution after the Y plane.
      final uvIndex = uvStart + (y >> 1) * rowStride + (x & ~1);
      final v = (uvIndex < bytes.length ? bytes[uvIndex] : 128) - 128;
      final u =
          (uvIndex + 1 < bytes.length ? bytes[uvIndex + 1] : 128) - 128;

      final r = (yValue + 1.402 * v).round().clamp(0, 255);
      final g = (yValue - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yValue + 1.772 * u).round().clamp(0, 255);
      out.setPixelRgb(ox, oy, r, g, b);
    }
  }
  return out;
}

img.Image _bgraToImage(CameraImage image, int targetWidth) {
  final width = image.width;
  final height = image.height;
  final plane = image.planes.first;
  final bytes = plane.bytes;
  final rowStride = plane.bytesPerRow;
  final step = (width / targetWidth).ceil().clamp(1, 16);

  final outW = (width / step).floor();
  final outH = (height / step).floor();
  final out = img.Image(width: outW, height: outH);

  for (var oy = 0; oy < outH; oy++) {
    final y = oy * step;
    for (var ox = 0; ox < outW; ox++) {
      final x = ox * step;
      final i = y * rowStride + x * 4;
      if (i + 2 >= bytes.length) continue;
      out.setPixelRgb(ox, oy, bytes[i + 2], bytes[i + 1], bytes[i]);
    }
  }
  return out;
}
