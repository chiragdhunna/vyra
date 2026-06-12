import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/fun_content.dart';

/// A playful card with three buttons (quote / joke / fact) and the latest
/// fetched result.
class FunCard extends StatelessWidget {
  const FunCard({super.key, required this.content, required this.onLoad});

  final AsyncValue<FunContent?> content;
  final ValueChanged<FunType> onLoad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A little delight', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              _PillButton(
                  icon: Icons.format_quote_rounded,
                  label: 'Quote',
                  onTap: () => onLoad(FunType.quote)),
              _PillButton(
                  icon: Icons.sentiment_very_satisfied_rounded,
                  label: 'Joke',
                  onTap: () => onLoad(FunType.joke)),
              _PillButton(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Fun fact',
                  onTap: () => onLoad(FunType.fact)),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _result(),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    return content.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Text(e.toString(), style: AppTextStyles.bodyMuted),
      data: (c) {
        if (c == null) {
          return Text(
            'Tap a button and I’ll fetch something fun ✨',
            style: AppTextStyles.bodyMuted,
          );
        }
        return Column(
          key: ValueKey(c.text),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.label.toUpperCase(), style: AppTextStyles.caption),
            const SizedBox(height: 6),
            Text(c.text, style: AppTextStyles.body),
            if (c.author != null && c.author!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('— ${c.author}', style: AppTextStyles.label),
            ],
          ],
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primarySoft),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
