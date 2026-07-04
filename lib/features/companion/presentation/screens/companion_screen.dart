import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../avatar/assets/anime_sprites.dart';
import '../../../avatar/presentation/widgets/anime_avatar.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../vision/providers/vision_provider.dart';
import '../../../voice/providers/voice_provider.dart';
import '../../providers/companion_provider.dart';
import '../../../../services/backend/realtime_events.dart';

/// Vyra's home — and, by design, the only thing you see.
///
/// **Anime mode (default) is fully immersive:** just her, filling the
/// screen. No captions, no buttons, no status text — like a person, not an
/// app. The camera runs for awareness (never shown) and the mic stays open.
///
///  * **tap** anywhere → mute / unmute (a ghost icon confirms, then fades)
///  * **long-press** → quiet options sheet (settings, chat & tools, status)
///  * a slim "reaching my brain…" pill appears only while the backend is
///    unreachable, and melts away once she's back
///
/// Classic orb mode keeps the original chrome (status chip, captions, mic
/// button) for people who prefer the informative look.
class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});

  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen>
    with WidgetsBindingObserver {
  bool _showMuteGhost = false;
  Timer? _ghostTimer;

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
    _ghostTimer?.cancel();
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

  void _toggleMute() {
    ref.read(companionControllerProvider.notifier).toggleMute();
    _ghostTimer?.cancel();
    setState(() => _showMuteGhost = true);
    _ghostTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showMuteGhost = false);
    });
  }

  void _openOptions() {
    final companion = ref.read(companionControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                companion.online
                    ? Icons.bolt_rounded
                    : Icons.cloud_off_rounded,
                color: companion.online
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
              title: Text(
                companion.brainLabel.isEmpty
                    ? 'Standalone'
                    : companion.brainLabel,
                style: AppTextStyles.body,
              ),
              subtitle: Text(
                companion.online ? 'Connected' : 'Reconnecting…',
                style: AppTextStyles.caption,
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.widgets_outlined, color: AppColors.primarySoft),
              title: Text('Chat & tools', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: AppColors.primarySoft),
              title: Text('Settings', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final anime =
        ref.watch(settingsProvider.select((s) => s.animeAvatar));
    return anime ? _buildImmersive(context) : _buildClassic(context);
  }

  // ------------------------------------------------------------------ //
  // Immersive: only her.
  // ------------------------------------------------------------------ //
  Widget _buildImmersive(BuildContext context) {
    final companion = ref.watch(companionControllerProvider);

    return Scaffold(
      // Painted with the sprites' exact background color so the frames blend
      // seamlessly — no card, no edges, only her.
      backgroundColor: AnimeSprites.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleMute,
        onLongPress: _openOptions,
        child: Container(
          color: AnimeSprites.background,
          child: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Her — as large as the screen allows (sprites are 2:3).
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxHeight / 1.5)
                        .clamp(0.0, constraints.maxWidth)
                        .toDouble();
                    return Center(child: AnimeAvatar(width: width * 0.96));
                  },
                ),

                // Transient mute/unmute confirmation ghost.
                AnimatedOpacity(
                  opacity: _showMuteGhost ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: Icon(
                      companion.micMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),

                // Slim pill, only while her brain is unreachable.
                if (!companion.online)
                  Positioned(
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('reaching my brain…',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ),

                // Persistent-but-quiet mute badge while muted.
                if (companion.micMuted && !_showMuteGhost)
                  Positioned(
                    bottom: 18,
                    child: Icon(
                      Icons.mic_off_rounded,
                      size: 18,
                      color: AppColors.textMuted.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Classic orb mode: the original informative layout.
  // ------------------------------------------------------------------ //
  Widget _buildClassic(BuildContext context) {
    final companion = ref.watch(companionControllerProvider);
    final voice = ref.watch(voiceControllerProvider);
    final vision = ref.watch(visionControllerProvider);

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
                onTools: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                ),
                onSettings: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
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
                child: _Caption(companion: companion, voice: voice),
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
  const _Caption({required this.companion, required this.voice});

  final CompanionState companion;
  final VoiceState voice;

  @override
  Widget build(BuildContext context) {
    if (voice.isListening) {
      return Text(
        voice.partialText.isEmpty ? 'Go ahead…' : voice.partialText,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMuted,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
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
