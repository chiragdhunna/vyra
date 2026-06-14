import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../assistant/presentation/screens/assistant_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import 'home_hub_screen.dart';

/// The app's main shell: a bottom navigation bar switching between the Home
/// hub, Chat, and the Assistant toolbox. Vision and Settings are pushed on top.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final pages = [
      HomeHubScreen(onSelectTab: _select),
      const ChatScreen(),
      const AssistantScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets_rounded),
            label: 'Tools',
          ),
        ],
      ),
    );
  }
}
