import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/flavor_config.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'services/service_providers.dart';
import 'shared/widgets/flavor_banner.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';

/// Root of the Vyra app. Picks the theme from user settings, shows a flavor
/// ribbon in non-prod builds, and routes first-run users through onboarding.
class VyraApp extends ConsumerWidget {
  const VyraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final onboardingDone = ref.read(storageServiceProvider).onboardingDone;

    return MaterialApp(
      title: FlavorConfig.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) =>
          FlavorBanner(child: child ?? const SizedBox.shrink()),
      home: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
