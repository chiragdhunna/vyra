import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../avatar/models/avatar_emotion.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../avatar/providers/avatar_provider.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../voice/presentation/widgets/voice_wave.dart';
import '../../../voice/providers/voice_provider.dart';
import '../../providers/vision_provider.dart';

/// "Live" companion mode: the animated Vyra avatar is the star and talks to
/// you, while the front camera runs quietly so she's aware of your presence
/// and smiles. Tap the mic to have a hands-free conversation (STT → Gemini →
/// spoken reply). Works fine even if the camera is unavailable.
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  final math.Random _rng = math.Random();
  String _caption = "I'm here — tap the mic and talk to me.";
  DateTime _lastSmileReact = DateTime.fromMillisecondsSinceEpoch(0);

  static const _greetings = [
    'Hey, there you are! 😊',
    'Oh, hi! Lovely to see you.',
    'There you are — how are you doing?',
    'Hey friend! Good to see your face.',
  ];
  static const _smileLines = [
    'I love that smile!',
    'That smile makes my day ✨',
    'Aww, you look happy!',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visionControllerProvider.notifier).start();
      ref.read(avatarControllerProvider.notifier).react(AvatarEmotion.caring);
    });
  }

  @override
  void dispose() {
    ref.read(visionControllerProvider.notifier).stop();
    super.dispose();
  }

  void _say(String line, AvatarEmotion emotion) {
    if (!mounted) return;
    setState(() => _caption = line);
    ref.read(avatarControllerProvider.notifier).react(emotion);
    ref.read(voiceControllerProvider.notifier).speak(line);
  }

  void _onPresenceChange(VisionState? prev, VisionState next) {
    final wasPresent = (prev?.faceCount ?? 0) > 0;
    final isPresent = next.faceCount > 0;
    if (!wasPresent && isPresent) {
      _say(_greetings[_rng.nextInt(_greetings.length)], AvatarEmotion.happy);
      return;
    }
    final smiling = next.smileProbability > 0.6;
    final cooled =
        DateTime.now().difference(_lastSmileReact) > const Duration(seconds: 12);
    if (isPresent && smiling && cooled) {
      _lastSmileReact = DateTime.now();
      _say(_smileLines[_rng.nextInt(_smileLines.length)], AvatarEmotion.excited);
    }
  }

  void _toggleMic() {
    final voice = ref.read(voiceControllerProvider);
    if (!voice.sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone isn't available")),
      );
      return;
    }
    ref.read(voiceControllerProvider.notifier).toggleListen(
          onFinal: ref.read(chatControllerProvider.notifier).send,
        );
  }

  @override
  Widget build(BuildContext context) {
    // React to what the camera sees.
    ref.listen<VisionState>(visionControllerProvider, _onPresenceChange);
    // Show Vyra's latest spoken reply as a caption.
    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, __) {
      final msgs = ref.read(chatControllerProvider).messages;
      for (final m in msgs.reversed) {
        if (!m.isUser) {
          if (mounted) setState(() => _caption = m.text);
          break;
        }
      }
    });

    final vision = ref.watch(visionControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final amplitude =
        ref.watch(avatarControllerProvider.select((s) => s.amplitude));
    final controller =
        ref.read(visionControllerProvider.notifier).cameraController;

    final seesYou = vision.faceCount > 0;
    final status = vision.error != null
        ? "Camera's off — but I can still hear you"
        : seesYou
            ? (vision.smileProbability > 0.6 ? 'I love that smile 😊' : 'I can see you 👀')
            : 'Looking for you…';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        Text('Live with Vyra', style: AppTextStyles.heading),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // The star: the talking avatar
                  const VyraAvatarLive(size: 260),
                  const SizedBox(height: 8),
                  _StatusChip(text: status, active: seesYou),
                  const SizedBox(height: 16),
                  // Caption + mic
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _CaptionBox(
                      listening: voice.isListening,
                      partial: voice.partialText,
                      caption: _caption,
                      amplitude: amplitude,
                    ),
                  ),
                  const Spacer(),
                  _MicButton(listening: voice.isListening, onTap: _toggleMic),
                  const SizedBox(height: 28),
                ],
              ),

              // Small camera awareness PiP (top-right)
              Positioned(
                top: 8,
                right: 12,
                child: _CameraPip(
                  controller:
                      vision.cameraReady ? controller : null,
                  faceCount: vision.faceCount,
                  error: vision.error,
                  onFlip: () =>
                      ref.read(visionControllerProvider.notifier).switchCamera(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (active ? AppColors.success : AppColors.textMuted)
              .withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.success : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

class _CaptionBox extends StatelessWidget {
  const _CaptionBox({
    required this.listening,
    required this.partial,
    required this.caption,
    required this.amplitude,
  });

  final bool listening;
  final String partial;
  final String caption;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    if (listening) {
      return Column(
        children: [
          VoiceWave(amplitude: amplitude, color: AppColors.accent, height: 36),
          const SizedBox(height: 8),
          Text(
            partial.isEmpty ? 'Listening…' : partial,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      caption,
      textAlign: TextAlign.center,
      style: AppTextStyles.body,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: listening ? null : AppColors.brandGradient,
          color: listening ? AppColors.error : null,
          boxShadow: [
            BoxShadow(
              color: (listening ? AppColors.error : AppColors.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          listening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

class _CameraPip extends StatelessWidget {
  const _CameraPip({
    required this.controller,
    required this.faceCount,
    required this.error,
    required this.onFlip,
  });

  final CameraController? controller;
  final int faceCount;
  final String? error;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onFlip,
      child: Container(
        width: 96,
        height: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: faceCount > 0
                ? AppColors.success.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.15),
            width: 2,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller!.value.previewSize?.height ?? 96,
                  height: controller!.value.previewSize?.width ?? 132,
                  child: CameraPreview(controller!),
                ),
              )
            else
              Center(
                child: Icon(
                  Icons.videocam_off_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  error != null
                      ? 'no camera'
                      : (faceCount > 0 ? '👁 sees you' : 'looking…'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
