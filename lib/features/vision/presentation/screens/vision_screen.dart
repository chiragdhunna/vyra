import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../providers/vision_provider.dart';
import '../widgets/face_overlay_painter.dart';

/// Camera-based vision: detects faces on-device and lets Vyra react to the
/// user's presence and smile. Nothing leaves the device.
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visionControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    ref.read(visionControllerProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visionControllerProvider);
    final controller = ref.read(visionControllerProvider.notifier).cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (state.cameraReady && controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    CustomPaint(
                      painter: FaceOverlayPainter(
                        faceRects: state.faceRects,
                        imageSize: state.imageSize,
                        rotation: state.rotation,
                        lensDirection: state.lensDirection,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _StatusFiller(state: state, onRetry: _retry),

          // Top bar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Text('Vision', style: AppTextStyles.heading),
                  const Spacer(),
                  const VyraAvatarLive(size: 64),
                ],
              ),
            ),
          ),

          // Bottom status + controls.
          if (state.cameraReady)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: _VisionStatusBar(state: state, onSwitch: _switch),
              ),
            ),
        ],
      ),
    );
  }

  void _retry() => ref.read(visionControllerProvider.notifier).start();
  void _switch() => ref.read(visionControllerProvider.notifier).switchCamera();
}

class _StatusFiller extends StatelessWidget {
  const _StatusFiller({required this.state, required this.onRetry});

  final VisionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.error != null) ...[
              const Icon(Icons.videocam_off_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(state.error!,
                    textAlign: TextAlign.center, style: AppTextStyles.bodyMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            ] else
              const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _VisionStatusBar extends StatelessWidget {
  const _VisionStatusBar({required this.state, required this.onSwitch});

  final VisionState state;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final seen = state.faceCount > 0;
    final smiling = state.smileProbability > 0.6;
    final message = !seen
        ? 'Looking for a face…'
        : smiling
            ? "Love that smile! 😊"
            : 'I see you 👀';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(
                  '${state.faceCount} face${state.faceCount == 1 ? '' : 's'} • on-device only',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: onSwitch,
          ),
        ],
      ),
    );
  }
}
