import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The chat composer: a growing text field plus a send button, and an optional
/// microphone button (wired up by the voice layer). When [onMic] is null the
/// mic is hidden, so this bar works standalone before voice is enabled.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.onMic,
    this.isListening = false,
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final VoidCallback? onMic;
  final bool isListening;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  hintText: widget.isListening
                      ? 'Listening…'
                      : 'Message Vyra…',
                  fillColor: AppColors.surface,
                ),
              ),
            ),
            if (widget.onMic != null) ...[
              const SizedBox(width: 8),
              _CircleButton(
                icon: widget.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                active: widget.isListening,
                onTap: widget.enabled ? widget.onMic : null,
              ),
            ],
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.arrow_upward_rounded,
              active: _hasText && widget.enabled,
              onTap: (_hasText && widget.enabled) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active ? AppColors.brandGradient : null,
          color: active ? null : AppColors.surfaceAlt,
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : AppColors.textMuted,
          size: 22,
        ),
      ),
    );
  }
}
