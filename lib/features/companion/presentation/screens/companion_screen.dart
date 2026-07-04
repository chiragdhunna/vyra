import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../avatar/providers/avatar_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../vision/providers/vision_provider.dart';
import '../../../voice/providers/voice_provider.dart';
import '../../providers/companion_provider.dart';
import '../../../../services/backend/realtime_events.dart';

/// Vyra's home — and, by design, almost the only thing you ever see.
///
/// The phone sits on the desk, this screen stays open, and Vyra is simply
/// *there*: her animated face front and center, camera awareness running
/// silently (never shown — you see her, she sees you), the mic open. No
/// chat bubbles, no tabs. The old multi-screen app still exists behind the
/// tools icon for the moments you want text chat or the assistant toolbox.
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Camera awareness only — the preview is never rendered.
      ref.read(visionControllerProvider.notifier).start();
      ref.read(companionControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(companionControllerProvider.notifier).stop();
    ref.read(visionControllerProvider.notifier).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(companionControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.setForeground(true);
      if (mounted) ref.read(visionControllerProvider.notifier).start();
    } else {
      controller.setForeground(false);
      ref.read(visionControllerProvider.notifier).stop();
    }
  }

  void _openClassic() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final companion = ref.watch(companionControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final vision = ref.watch(visionControllerProvider);
    final amplitude =
        ref.watch(avatarControllerProvider.select((s) => s.amplitude));

    final status = _statusText(companion, voice, vision.faceCount > 0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                brainLabel: companion.brainLabel,
                online: companion.online,
                onTools: _openClassic,
                onSettings: _openSettings,
              ),
              const Spacer(),
              const VyraAvatarLive(size: 300),
              const SizedBox(height: 14),
              _StatusChip(
                text: status,
                active: companion.online &&
                    (companion.phase == CompanionPhase.listening ||
                        voice.isListening),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _Caption(
                  companion: companion,
                  voice: voice,
                  amplitude: amplitude,
                ),
              ),
              const Spacer(),
              _MicButton(
                muted: companion.micMuted,
                listening: companion.phase == CompanionPhase.listening ||
                    voice.isListening,
                onTap: () => ref
                    .read(companionControllerProvider.notifier)
                    .toggleMute(),
              ),
              const SizedBox(height: 10),
              Text(
                companion.micMuted
                    ? 'Tap when you want me to listen again'
                    : "I'm listening — just talk to me",
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(
    CompanionState companion,
    VoiceState voice,
    bool seesYou,
  ) {
    if (companion.micMuted) return 'Paused';
    if (!companion.online) return 'Reaching my brain…';
    if (voice.isSpeaking || companion.phase == CompanionPhase.speaking) {
      return 'Speaking…';
    }
    if (companion.phase == CompanionPhase.thinking) return 'Thinking…';
    if (voice.isListening) return 'Listening…';
    if (companion.phase == CompanionPhase.listening) {
      return seesYou ? 'With you 👀' : 'Listening…';
    }
    return "I'm here";
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.brainLabel,
    required this.online,
    required this.onTools,
    required this.onSettings,
  });

  final String brainLabel;
  final bool online;
  final VoidCallback onTools;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          if (brainLabel.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    online ? Icons.bolt_rounded : Icons.cloud_off_rounded,
                    size: 14,
                    color: online ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(brainLabel, style: AppTextStyles.caption),
                ],
              ),
            ),
          const Spacer(),
          IconButton(
            tooltip: 'Chat & tools',
            icon: const Icon(Icons.widgets_outlined),
            color: AppColors.textMuted,
            onPressed: onTools,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.textMuted,
            onPressed: onSettings,
          ),
        ],
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

class _Caption extends StatelessWidget {
  const _Caption({
    required this.companion,
    required this.voice,
    required this.amplitude,
  });

  final CompanionState companion;
  final VoiceState voice;
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    // Turn-based modes show your live partial transcript while you speak.
    if (voice.isListening) {
      return Column(
        children: [
          Text(
            voice.partialText.isEmpty ? 'Go ahead…' : voice.partialText,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      companion.caption,
      textAlign: TextAlign.center,
      style: AppTextStyles.body,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.muted,
    required this.listening,
    required this.onTap,
  });

  final bool muted;
  final bool listening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = !muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active ? AppColors.brandGradient : null,
          color: active ? null : AppColors.surfaceAlt,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (listening ? AppColors.accent : AppColors.primary)
                        .withValues(alpha: 0.45),
                    blurRadius: listening ? 30 : 16,
                    spreadRadius: listening ? 4 : 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          active ? Icons.mic_rounded : Icons.mic_off_rounded,
          color: active ? Colors.white : AppColors.textMuted,
          size: 30,
        ),
      ),
    );
  }
}
