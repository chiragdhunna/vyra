import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../services/voice/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../chat/providers/chat_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppColors.sync(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionLabel('You'),
            _SettingTile(
              icon: Icons.badge_outlined,
              title: 'Your name',
              subtitle: settings.userName.isEmpty ? 'Not set' : settings.userName,
              onTap: () => _editName(context, ref, settings.userName),
            ),

            const SizedBox(height: 16),
            _SectionLabel('Voice'),
            _SwitchTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Spoken replies',
              subtitle: 'Vyra reads her answers aloud',
              value: settings.ttsEnabled,
              onChanged: notifier.setTtsEnabled,
            ),
            _SwitchTile(
              icon: Icons.mic_none_rounded,
              title: 'Voice input',
              subtitle: 'Show the microphone in chat',
              value: settings.voiceEnabled,
              onChanged: notifier.setVoiceEnabled,
            ),
            _SpeechRateTile(
              value: settings.speechRate,
              onChanged: notifier.setSpeechRate,
            ),
            _SettingTile(
              icon: Icons.graphic_eq_rounded,
              title: "Vyra's voice",
              subtitle: settings.voiceName.isEmpty
                  ? 'Auto (device default)'
                  : settings.voiceName,
              onTap: () => _pickVoice(context, ref),
            ),
            _PitchTile(
              value: settings.voicePitch,
              onChanged: notifier.setVoicePitch,
              onChangeEnd: (_) => TtsService.instance.sample(),
            ),

            const SizedBox(height: 16),
            _SectionLabel('Appearance'),
            _SwitchTile(
              icon: Icons.face_retouching_natural_rounded,
              title: 'Anime companion',
              subtitle: settings.animeAvatar
                  ? 'Vyra appears as her anime self'
                  : 'Classic glowing orb face',
              value: settings.animeAvatar,
              onChanged: (v) => notifier.setAvatarStyle(v ? 'anime' : 'orb'),
            ),
            _ThemeTile(
              mode: settings.themeMode,
              onChanged: notifier.setThemeMode,
            ),

            const SizedBox(height: 16),
            _SectionLabel('Data'),
            _SettingTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear chat history',
              subtitle: 'Erase your conversation on this device',
              onTap: () => _clearChat(context, ref),
            ),

            const SizedBox(height: 24),
            _About(),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVoice(BuildContext context, WidgetRef ref) async {
    final tts = TtsService.instance;
    final voices = await tts.englishVoices();
    if (!context.mounted) return;
    if (voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No voices reported by this device.')),
      );
      return;
    }
    final current = ref.read(settingsProvider).voiceName;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Vyra's voice", style: AppTextStyles.title),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: ListView.builder(
            itemCount: voices.length,
            itemBuilder: (context, i) {
              final v = voices[i];
              final selected = v['name'] == current;
              return ListTile(
                dense: true,
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
                title: Text(v['name']!,
                    style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                subtitle: Text(v['locale']!, style: AppTextStyles.caption),
                onTap: () async {
                  // Apply + audition immediately; persist the choice.
                  await tts.applyVoice(v['name']!, v['locale']!);
                  await ref
                      .read(settingsProvider.notifier)
                      .setVoice(v['name']!, v['locale']!);
                  unawaited(tts.sample());
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Your name', style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What should I call you?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) ref.read(settingsProvider.notifier).setUserName(name);
  }

  Future<void> _clearChat(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear chat history?', style: AppTextStyles.title),
        content: Text('This cannot be undone.', style: AppTextStyles.bodyMuted),
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
    if (ok == true) {
      ref.read(chatControllerProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat history cleared')),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text.toUpperCase(), style: AppTextStyles.caption),
      );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primarySoft),
        title: Text(title, style: AppTextStyles.body),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primarySoft),
        title: Text(title, style: AppTextStyles.body),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        value: value,
        activeColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _PitchTile extends StatelessWidget {
  const _PitchTile({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primarySoft),
                const SizedBox(width: 12),
                Text('Voice pitch', style: AppTextStyles.body),
              ],
            ),
            Slider(
              value: value.clamp(0.8, 1.6).toDouble(),
              min: 0.8,
              max: 1.6,
              divisions: 8,
              activeColor: AppColors.accent,
              label: value < 1.05
                  ? 'Deeper'
                  : value > 1.35
                      ? 'Higher'
                      : 'Bright',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechRateTile extends StatelessWidget {
  const _SpeechRateTile({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: AppColors.primarySoft),
                const SizedBox(width: 12),
                Text('Speaking rate', style: AppTextStyles.body),
              ],
            ),
            Slider(
              value: value.clamp(0.2, 0.9).toDouble(),
              min: 0.2,
              max: 0.9,
              divisions: 7,
              activeColor: AppColors.accent,
              label: value < 0.45
                  ? 'Slow'
                  : value > 0.65
                      ? 'Fast'
                      : 'Normal',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.mode, required this.onChanged});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined, color: AppColors.primarySoft),
                const SizedBox(width: 12),
                Text('Theme', style: AppTextStyles.body),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(AppConstants.appName, style: AppTextStyles.heading),
        const SizedBox(height: 4),
        Text('v1.0.0  •  Powered by Google Gemini',
            style: AppTextStyles.caption),
        const SizedBox(height: 6),
        Text(
          'Vyra processes vision on-device. Your conversations stay on your phone.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
