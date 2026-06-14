import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../assistant/data/models/fun_content.dart';
import '../../../assistant/providers/assistant_provider.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../chat/providers/chat_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../vision/presentation/screens/vision_screen.dart';
import '../../../voice/providers/voice_provider.dart';
import '../widgets/quick_action_card.dart';

/// The "Home" tab: a big living avatar, a warm greeting, and quick actions into
/// every Vyra capability.
class HomeHubScreen extends ConsumerWidget {
  const HomeHubScreen({super.key, required this.onSelectTab});

  /// Switches the bottom-nav tab (0 home, 1 chat, 2 assistant).
  final ValueChanged<int> onSelectTab;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppColors.sync(context);
    final name = ref.watch(settingsProvider.select((s) => s.userName));
    final greeting = name.isEmpty ? _greeting() : '${_greeting()}, $name';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting, style: AppTextStyles.bodyMuted),
                          Text("I'm Vyra", style: AppTextStyles.headingLarge),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => onSelectTab(1),
                    child: const VyraAvatarLive(size: 230),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How can I help today?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading,
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.25,
                  children: [
                    QuickActionCard(
                      icon: Icons.chat_bubble_rounded,
                      title: 'Chat',
                      subtitle: 'Ask me anything',
                      color: AppColors.primary,
                      onTap: () => onSelectTab(1),
                    ),
                    QuickActionCard(
                      icon: Icons.mic_rounded,
                      title: 'Talk',
                      subtitle: 'Use your voice',
                      color: AppColors.accent,
                      onTap: () => _startVoice(ref),
                    ),
                    QuickActionCard(
                      icon: Icons.video_camera_front_rounded,
                      title: 'Live',
                      subtitle: 'Talk face-to-face',
                      color: AppColors.accentPink,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VisionScreen()),
                      ),
                    ),
                    QuickActionCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Surprise me',
                      subtitle: 'A little delight',
                      color: AppColors.warning,
                      onTap: () {
                        ref.read(funContentProvider.notifier).load(FunType.joke);
                        onSelectTab(2);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startVoice(WidgetRef ref) {
    onSelectTab(1);
    final voice = ref.read(voiceControllerProvider);
    if (!voice.sttAvailable) return;
    ref.read(voiceControllerProvider.notifier).startListening(
          onFinal: ref.read(chatControllerProvider.notifier).send,
        );
  }
}
