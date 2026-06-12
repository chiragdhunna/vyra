import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/chat_message.dart';

/// A single chat bubble. User messages sit right with the brand gradient;
/// Vyra's messages sit left on a surface card, tinted by the reply's emotion.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    final time = DateFormat('h:mm a').format(message.timestamp);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser ? AppColors.brandGradient : null,
        color: isUser
            ? null
            : (message.isError
                ? AppColors.error.withValues(alpha: 0.16)
                : AppColors.surface),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
        border: isUser
            ? null
            : Border.all(
                color: message.emotion.color.withValues(alpha: 0.35),
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          SelectableText(
            message.text,
            style: AppTextStyles.body.copyWith(
              color: isUser ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUser ? time : '${message.emotion.emoji}  $time',
            style: AppTextStyles.caption.copyWith(
              color: isUser
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }
}
