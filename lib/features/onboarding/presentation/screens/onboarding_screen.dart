import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/service_providers.dart';
import '../../../avatar/models/avatar_emotion.dart';
import '../../../avatar/presentation/widgets/vyra_avatar.dart';
import '../../../avatar/providers/avatar_provider.dart';
import '../../../companion/presentation/screens/companion_screen.dart';

class _Page {
  final AvatarEmotion emotion;
  final String title;
  final String body;
  const _Page(this.emotion, this.title, this.body);
}

const _pages = [
  _Page(AvatarEmotion.happy, 'Meet Vyra',
      'Your personal AI companion — warm, expressive, and always here for you.'),
  _Page(AvatarEmotion.excited, 'Talk, type, or just smile',
      'Chat with Gemini-powered intelligence, speak hands-free, and let Vyra see your smile.'),
  _Page(AvatarEmotion.caring, 'Let’s get to know each other',
      'What should Vyra call you?'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  final TextEditingController _name = TextEditingController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(avatarControllerProvider.notifier).setEmotion(_pages.first.emotion);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    ref.read(avatarControllerProvider.notifier).setEmotion(_pages[i].emotion);
  }

  Future<void> _next() async {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: AppConstants.medium,
        curve: Curves.easeOut,
      );
      return;
    }
    // Finish onboarding.
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      await ref.read(settingsProvider.notifier).setUserName(name);
    }
    await ref.read(storageServiceProvider).setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CompanionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const VyraAvatarLive(size: 220),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: _onPageChanged,
                  itemCount: _pages.length,
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(page.title,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headingLarge),
                          const SizedBox(height: 12),
                          Text(page.body,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMuted),
                          if (i == _pages.length - 1) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: _name,
                              textAlign: TextAlign.center,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _next(),
                              decoration:
                                  const InputDecoration(hintText: 'Your name (optional)'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              _Dots(count: _pages.length, index: _index),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: AppConstants.fast,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
