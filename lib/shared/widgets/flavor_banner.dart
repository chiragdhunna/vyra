import 'package:flutter/material.dart';

import '../../core/config/flavor_config.dart';
import '../../core/theme/app_colors.dart';

/// Shows a small corner ribbon ("dev" / "staging") in non-production flavors,
/// and passes the child through untouched in production.
class FlavorBanner extends StatelessWidget {
  const FlavorBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!FlavorConfig.showFlavorBanner) return child;
    return Banner(
      message: FlavorConfig.name,
      location: BannerLocation.topStart,
      color: AppColors.accentPink,
      child: child,
    );
  }
}
