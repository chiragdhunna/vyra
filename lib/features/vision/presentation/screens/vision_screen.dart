import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../avatar/models/avatar_emotion.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../avatar/providers/avatar_provider.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../voice/presentation/widgets/voice_wave.dart';
import '../../../voice/providers/voice_provider.dart';
import '../../providers/vision_provider.dart';

/// "Live" companion mode — turn-based hands-free.
///
/// Native speech recognizers can't truly stay on forever (they endpoint per
/// utterance), so instead of brute-force restarting (which caused the mic to
/// flap on/off) we take turns: the mic opens for the user's turn, ends when
/// they pause, Vyra replies, then the mic auto-reopens for the next turn. After
/// a lull she re-engages a few times, then waits. Tap the mic to pause/resume.
class VisionScreen extends ConsumerStatefulWidget {
  const VisionScreen({super.key});

  @override
  ConsumerState<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends ConsumerState<VisionScreen>
    with WidgetsBindingObserver {
  final math.Random _rng = math.Random();
  String _caption = "Hey! I'm right here — let's talk.";
  bool _handsFree = true; // false = paused/muted by the user
  bool _foreground = true;
  bool _spoke = false;
  int _consecutiveNudges = 0;
  DateTime _lastSmileReact = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastInteraction = DateTime.now();
  DateTime _lastListenStart = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tick;

  VisionController? _visionCtrl;
  VoiceController? _voiceCtrl;

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
    'What have you been up to lately?',
    "I'm curious — what's something you're into these days?",
    'Got anything fun coming up?',
    'Want to hear a joke, or shall we just chat?',
  ];

  bool get _ttsOn => ref.read(settingsProvider).ttsEnabled;

  @override
  void initState() {
    super.initState();
    _visionCtrl = ref.read(visionControllerProvider.notifier);
    _voiceCtrl = ref.read(voiceControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visionCtrl?.start(); // awareness only — preview never shown
      ref.read(avatarControllerProvider.notifier).react(AvatarEmotion.caring);
      // Make her break the ice almost immediately (then she opens the mic).
      _lastInteraction = DateTime.now().subtract(const Duration(seconds: 13));
      _tick = Timer.periodic(const Duration(seconds: 2), (_) => _onTick());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _voiceCtrl?.stopListening();
    _visionCtrl?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (mounted) _visionCtrl?.start();
    } else {
      _foreground = false;
      _voiceCtrl?.stopListening();
      _visionCtrl?.stop();
    }
  }

  // Proactive re-engagement only — NOT a listening restart (that's what caused
  // the flapping). After a lull she asks something, which then reopens the mic.
  void _onTick() {
    if (!mounted || !_foreground || !_handsFree) return;
    final voice = ref.read(voiceControllerProvider);
    final responding = ref.read(chatControllerProvider).isResponding;
    if (voice.isListening || voice.isSpeaking || responding) return;
    if (_consecutiveNudges >= 3) return; // she's said enough; wait for the user
    if (DateTime.now().difference(_lastInteraction) >=
        const Duration(seconds: 15)) {
      _consecutiveNudges++;
      _speakOpener();
    }
  }

  // Open the mic for the user's turn (guarded + throttled).
  void _armListening() {
    if (!mounted || !_handsFree || !_foreground) return;
    final voice = ref.read(voiceControllerProvider);
    final responding = ref.read(chatControllerProvider).isResponding;
    if (voice.isListening ||
        voice.isSpeaking ||
        responding ||
        !voice.sttAvailable) {
      return;
    }
    if (DateTime.now().difference(_lastListenStart) <
        const Duration(milliseconds: 800)) {
      return;
    }
    _lastListenStart = DateTime.now();
    ref.read(voiceControllerProvider.notifier).startListening(onFinal: _onHeard);
  }

  void _onHeard(String text) {
    _consecutiveNudges = 0;
    _lastInteraction = DateTime.now();
    ref.read(chatControllerProvider.notifier).send(text);
  }

  void _speakOpener() {
    _say(
      _openers[_rng.nextInt(_openers.length)],
      _rng.nextBool() ? AvatarEmotion.happy : AvatarEmotion.caring,
    );
  }

  void _say(String line, AvatarEmotion emotion) {
    if (!mounted) return;
    _spoke = true;
    setState(() => _caption = line);
    _lastInteraction = DateTime.now();
    ref.read(avatarControllerProvider.notifier).react(emotion);
    ref.read(voiceControllerProvider.notifier).speak(line);
    // If TTS is off there's no "speak complete" event to reopen the mic.
    if (!_ttsOn) {
      Future.delayed(const Duration(milliseconds: 700), _armListening);
    }
  }

  void _onPresenceChange(VisionState? prev, VisionState next) {
    final wasPresent = (prev?.faceCount ?? 0) > 0;
    final isPresent = next.faceCount > 0;
    if (!wasPresent && isPresent && !_spoke) {
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

  // When Vyra finishes speaking, it's the user's turn → reopen the mic.
  void _onVoiceChange(VoiceState? prev, VoiceState next) {
    if ((prev?.isSpeaking ?? false) && !next.isSpeaking) {
      _armListening();
    }
  }

  void _toggleMic() {
    if (_handsFree) {
      setState(() => _handsFree = false);
      ref.read(voiceControllerProvider.notifier).stopListening();
    } else {
      setState(() => _handsFree = true);
      _consecutiveNudges = 0;
      _lastInteraction = DateTime.now();
      _armListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VisionState>(visionControllerProvider, _onPresenceChange);
    ref.listen<VoiceState>(voiceControllerProvider, _onVoiceChange);
    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, __) {
      final msgs = ref.read(chatControllerProvider).messages;
      for (final m in msgs.reversed) {
        if (!m.isUser) {
          _lastInteraction = DateTime.now();
          if (mounted) setState(() => _caption = m.text);
          // With TTS off, reopen the mic after her (silent) reply.
          if (!_ttsOn) {
            Future.delayed(const Duration(milliseconds: 600), _armListening);
          }
          break;
        }
      }
    });

    final vision = ref.watch(visionControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final responding =
        ref.watch(chatControllerProvider.select((s) => s.isResponding));
    final amplitude =
        ref.watch(avatarControllerProvider.select((s) => s.amplitude));

    final seesYou = vision.faceCount > 0;
    final status = !_handsFree
        ? 'Paused'
        : voice.isListening
            ? 'Listening…'
            : voice.isSpeaking
                ? 'Speaking…'
                : responding
                    ? 'Thinking…'
                    : (seesYou ? 'I can see you 👀' : "I'm here");

    final hint = !_handsFree
        ? 'Tap to talk hands-free'
        : voice.isListening
            ? 'Go ahead, I’m listening…'
            : voice.isSpeaking
                ? 'Speaking…'
                : responding
                    ? 'Thinking…'
                    : 'Tap if I don’t catch you';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
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
              _StatusChip(text: status, active: voice.isListening || seesYou),
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
              _MicButton(
                handsFree: _handsFree,
                listening: voice.isListening,
                onTap: _toggleMic,
              ),
              const SizedBox(height: 12),
              Text(hint, style: AppTextStyles.caption),
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
  const _MicButton({
    required this.handsFree,
    required this.listening,
    required this.onTap,
  });
  final bool handsFree;
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = handsFree;
    final accent = listening ? AppColors.accent : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active ? AppColors.brandGradient : null,
          color: active ? null : AppColors.surfaceAlt,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: listening ? 30 : 16,
                    spreadRadius: listening ? 4 : 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          active ? Icons.mic_rounded : Icons.mic_off_rounded,
          color: active ? Colors.white : AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }
}
