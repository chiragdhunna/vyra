import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../avatar/providers/avatar_provider.dart';
import '../../../voice/presentation/widgets/voice_wave.dart';
import '../../../voice/providers/voice_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';

/// The main conversation screen: a compact reactive avatar header, the message
/// list, a typing indicator, and the composer.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: AppConstants.medium,
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear conversation?', style: AppTextStyles.title),
        content: Text(
          'This will erase your chat history with Vyra on this device.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(chatControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      chatControllerProvider.select((s) => s.messages.length),
      (_, __) => _scrollToBottom(),
    );

    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final voice = ref.watch(voiceControllerProvider);
    final amplitude =
        ref.watch(avatarControllerProvider.select((s) => s.amplitude));
    final itemCount = state.messages.length + (state.isResponding ? 1 : 0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _ChatHeader(onClear: _confirmClear),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index >= state.messages.length) {
                      return const TypingIndicator();
                    }
                    return MessageBubble(message: state.messages[index]);
                  },
                ),
              ),
              if (voice.isListening)
                _ListeningBanner(
                  amplitude: amplitude,
                  partial: voice.partialText,
                ),
              ChatInputBar(
                onSend: controller.send,
                enabled: !state.isResponding,
                isListening: voice.isListening,
                onMic: () {
                  if (!voice.sttAvailable) {
                    context.showSnack("Microphone isn't available");
                    return;
                  }
                  ref
                      .read(voiceControllerProvider.notifier)
                      .toggleListen(onFinal: controller.send);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListeningBanner extends StatelessWidget {
  const _ListeningBanner({required this.amplitude, required this.partial});

  final double amplitude;
  final String partial;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceWave(amplitude: amplitude, color: AppColors.accent, height: 34),
          const SizedBox(height: 6),
          Text(
            partial.isEmpty ? 'Listening…' : partial,
            style: AppTextStyles.bodyMuted,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarControllerProvider);
    final responding = ref.watch(
      chatControllerProvider.select((s) => s.isResponding),
    );
    final status = responding
        ? 'thinking…'
        : 'feeling ${avatar.emotion.label.toLowerCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          const VyraAvatarLive(size: 72),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConstants.appName, style: AppTextStyles.heading),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: responding
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(status, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear chat',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
