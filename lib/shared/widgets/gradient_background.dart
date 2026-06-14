import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Vyra's signature deep-space gradient backdrop. Wrap a screen's body to get a
/// consistent canvas for the glowing avatar and glass cards.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.safeArea = true});

  final Widget child;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
      child: safeArea ? SafeArea(child: child) : child,
    );
  }
}
