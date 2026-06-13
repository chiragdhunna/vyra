import 'dart:async';
import 'dart:math' as math;

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

/// "Live" companion mode. Only Vyra's animated face is shown — the front camera
/// stays on purely for awareness (face presence / smiles), it is never
/// displayed. Vyra talks first, asks questions, reacts to your tone (Gemini
/// drives her emotion, including hurt/cry), and you reply hands-free with the
/// mic (STT → Gemini → spoken reply).
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen> {
  final math.Random _rng = math.Random();
  String _caption = "Hey! I'm right here — let's talk.";
  DateTime _lastSmileReact = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInteraction = DateTime.now();
  Timer? _nudgeTimer;

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
  static const _openers = [
    "So, what's on your mind today?",
    'How are you really doing?',
    'Tell me something good that happened recently.',
    "What have you been up to lately?",
    "I'm curious — what's something you're into these days?",
    'Got anything fun coming up?',
    'Want to hear a joke, or shall we just chat?',
    'If you could do anything right now, what would it be?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Camera runs for awareness only — its preview is never shown.
      ref.read(visionControllerProvider.notifier).start();
      ref.read(avatarControllerProvider.notifier).react(AvatarEmotion.caring);

      // Open the conversation herself, like a friend would.
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        final v = ref.read(voiceControllerProvider);
        if (!v.isListening && !v.isSpeaking) _speakOpener();
      });
      _nudgeTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _maybeNudge());
    });
  }

  @override
  void dispose() {
    _nudgeTimer?.cancel();
    ref.read(visionControllerProvider.notifier).stop();
    super.dispose();
  }

  // Re-engage after a stretch of silence (a friend doesn't just go quiet).
  void _maybeNudge() {
    if (!mounted) return;
    final v = ref.read(voiceControllerProvider);
    if (v.isListening || v.isSpeaking) return;
    if (DateTime.now().difference(_lastInteraction) >=
        const Duration(seconds: 22)) {
      _speakOpener();
    }
  }

  void _speakOpener() {
    _say(
      _openers[_rng.nextInt(_openers.length)],
      _rng.nextBool() ? AvatarEmotion.happy : AvatarEmotion.caring,
    );
  }

  void _say(String line, AvatarEmotion emotion) {
    if (!mounted) return;
    setState(() => _caption = line);
    _lastInteraction = DateTime.now();
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
    final cooled = DateTime.now().difference(_lastSmileReact) >
        const Duration(seconds: 12);
    if (isPresent && smiling && cooled) {
      _lastSmileReact = DateTime.now();
      _say(_smileLines[_rng.nextInt(_smileLines.length)], AvatarEmotion.excited);
    }
  }

  void _toggleMic() {
    _lastInteraction = DateTime.now();
    final voice = ref.read(voiceControllerProvider);
    if (!voice.sttAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone isn't available")),
      );
      return;
    }
    ref.read(voiceControllerProvider.notifier).toggleListen(
      onFinal: (text) {
        _lastInteraction = DateTime.now();
        ref.read(chatControllerProvider.notifier).send(text);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VisionState>(visionControllerProvider, _onPresenceChange);
    // Mirror Vyra's latest spoken reply into the caption.
    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, __) {
      final msgs = ref.read(chatControllerProvider).messages;
      for (final m in msgs.reversed) {
        if (!m.isUser) {
          _lastInteraction = DateTime.now();
          if (mounted) setState(() => _caption = m.text);
          break;
        }
      }
    });

    final vision = ref.watch(visionControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final amplitude =
        ref.watch(avatarControllerProvider.select((s) => s.amplitude));

    final seesYou = vision.faceCount > 0;
    final status = vision.error != null
        ? "I can't see, but I'm all ears"
        : seesYou
            ? (vision.smileProbability > 0.6
                ? 'Love that smile 😊'
                : 'I can see you 👀')
            : "I'm right here";

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
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
              const VyraAvatarLive(size: 280),
              const SizedBox(height: 10),
              _StatusChip(text: status, active: seesYou),
              const SizedBox(height: 18),
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
              const SizedBox(height: 12),
              Text(
                voice.isListening ? 'Tap to stop' : 'Tap to talk',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 24),
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
