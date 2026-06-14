import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/chat_conversation.dart';
import '../../providers/chat_provider.dart';

/// Browse, reopen and manage past conversations with Vyra (issue #8).
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(
      chatControllerProvider.select((s) => s.conversations),
    );
    final activeId =
        ref.watch(chatControllerProvider.select((s) => s.activeId));
    final controller = ref.read(chatControllerProvider.notifier);

    // Defensive: present most-recent first regardless of internal ordering.
    final sorted = [...conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat history'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              controller.newConversation();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: sorted.isEmpty
              ? const _EmptyHistory()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final convo = sorted[i];
                    return _ConversationTile(
                      conversation: convo,
                      isActive: convo.id == activeId,
                      onOpen: () {
                        controller.openConversation(convo.id);
                        Navigator.of(context).pop();
                      },
                      onDelete: () =>
                          _confirmDelete(context, controller, convo),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChatController controller,
    ChatConversation convo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this chat?', style: AppTextStyles.title),
        content: Text(
          '“${convo.displayTitle}” will be removed from this device. This '
          "can't be undone.",
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) controller.deleteConversation(convo.id);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
  });

  final ChatConversation conversation;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: isActive
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.6))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            conversation.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.title,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Current',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.accent)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMuted,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_relativeTime(conversation.updatedAt)} • '
                      '${conversation.messageCount} message'
                      '${conversation.messageCount == 1 ? '' : 's'}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(t);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                color: AppColors.textMuted, size: 44),
            const SizedBox(height: 12),
            Text('No conversations yet',
                style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Your chats with Vyra will show up here so you can pick any of '
              'them back up later.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
