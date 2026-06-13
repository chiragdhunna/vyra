import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/utils/app_logger.dart';
import '../../../services/vision/face_detection_service.dart';
import '../../avatar/models/avatar_emotion.dart';
import '../../avatar/providers/avatar_provider.dart';

final faceDetectionServiceProvider =
    Provider<FaceDetectionService>((ref) => FaceDetectionService.instance);

@immutable
class VisionState {
  final bool initializing;
  final bool active;
  final bool cameraReady;
  final String? error;
  final int faceCount;
  final double smileProbability;
  final List<Rect> faceRects;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  const VisionState({
    this.initializing = false,
    this.active = false,
    this.cameraReady = false,
    this.error,
    this.faceCount = 0,
    this.smileProbability = 0,
    this.faceRects = const [],
    this.imageSize = Size.zero,
    this.rotation = InputImageRotation.rotation0deg,
    this.lensDirection = CameraLensDirection.front,
  });

  VisionState copyWith({
    bool? initializing,
    bool? active,
    bool? cameraReady,
    String? error,
    int? faceCount,
    double? smileProbability,
    List<Rect>? faceRects,
    Size? imageSize,
    InputImageRotation? rotation,
    CameraLensDirection? lensDirection,
    bool clearError = false,
  }) =>
      VisionState(
        initializing: initializing ?? this.initializing,
        active: active ?? this.active,
        cameraReady: cameraReady ?? this.cameraReady,
        error: clearError ? null : (error ?? this.error),
        faceCount: faceCount ?? this.faceCount,
        smileProbability: smileProbability ?? this.smileProbability,
        faceRects: faceRects ?? this.faceRects,
        imageSize: imageSize ?? this.imageSize,
        rotation: rotation ?? this.rotation,
        lensDirection: lensDirection ?? this.lensDirection,
      );
}

/// Owns the camera lifecycle and streams frames through ML Kit, then makes
/// Vyra react to the user's presence and smile. Frames are throttled (one in
/// flight at a time) to keep things smooth.
class VisionController extends StateNotifier<VisionState> {
  VisionController(this._ref) : super(const VisionState());

  final Ref _ref;
  CameraController? _camera;
  bool _busy = false;
  CameraLensDirection _lens = CameraLensDirection.front;
  AvatarEmotion _lastEmotion = AvatarEmotion.neutral;

  CameraController? get cameraController => _camera;
  FaceDetectionService get _service =>
      _ref.read(faceDetectionServiceProvider);
  AvatarController get _avatar =>
      _ref.read(avatarControllerProvider.notifier);

  Future<void> start() async {
    if (state.active || state.initializing) return;
    state = state.copyWith(initializing: true, clearError: true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(
            initializing: false, error: 'No camera available on this device.');
        return;
      }
      final desc = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      _lens = desc.lensDirection;
      final controller = CameraController(
        desc,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      _camera = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(_process);
      state = state.copyWith(
        initializing: false,
        active: true,
        cameraReady: true,
        lensDirection: _lens,
      );
    } catch (e, st) {
      AppLogger.e('Camera start failed', error: e, stackTrace: st, tag: 'Vision');
      state = state.copyWith(
        initializing: false,
        error: 'Camera unavailable. Please grant camera permission.',
      );
    }
  }

  Future<void> _process(CameraImage image) async {
    if (_busy || !mounted || _camera == null) return;
    _busy = true;
    try {
      final input =
          _service.inputImageFromCamera(image, _camera!, _camera!.description);
      if (input == null) return;
      final faces = await _service.detect(input);
      if (!mounted) return;

      var smile = 0.0;
      for (final f in faces) {
        final p = f.smilingProbability ?? 0;
        if (p > smile) smile = p;
      }
      state = state.copyWith(
        faceCount: faces.length,
        smileProbability: smile,
        faceRects: faces.map((f) => f.boundingBox).toList(),
        imageSize: input.metadata?.size ?? state.imageSize,
        rotation: input.metadata?.rotation ?? state.rotation,
      );
      _react(faces.length, smile);
    } finally {
      _busy = false;
    }
  }

  void _react(int count, double smile) {
    final target = count == 0
        ? AvatarEmotion.neutral
        : (smile > 0.6 ? AvatarEmotion.happy : AvatarEmotion.caring);
    if (target != _lastEmotion) {
      _lastEmotion = target;
      _avatar.react(target);
    }
  }

  Future<void> switchCamera() async {
    _lens = _lens == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    await stop();
    await start();
  }

  Future<void> stop() async {
    final cam = _camera;
    _camera = null;
    if (mounted) {
      state = state.copyWith(
        active: false,
        cameraReady: false,
        faceCount: 0,
        faceRects: const [],
      );
    }
    _avatar.react(AvatarEmotion.neutral, activity: AvatarActivity.idle);
    if (cam == null) return;
    // Stop the image stream and release the camera INDEPENDENTLY: if
    // stopImageStream throws (a common race when the screen is torn down),
    // dispose() must still run — that's what frees the hardware and clears the
    // "camera in use" indicator.
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (e) {
      AppLogger.w('stopImageStream failed: $e', tag: 'Vision');
    }
    try {
      await cam.dispose();
    } catch (e) {
      AppLogger.w('camera dispose failed: $e', tag: 'Vision');
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final visionControllerProvider =
    StateNotifierProvider<VisionController, VisionState>(
  (ref) => VisionController(ref),
);
