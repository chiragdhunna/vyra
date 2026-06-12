import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../services/service_providers.dart';
import '../../data/models/fun_content.dart';
import '../../providers/assistant_provider.dart';
import '../widgets/fun_card.dart';
import '../widgets/reminder_tile.dart';
import '../widgets/weather_card.dart';

/// The assistant toolbox: live weather, reminders, and a little delight.
class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    final reminders = ref.watch(remindersProvider);
    final fun = ref.watch(funContentProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text('Assistant', style: AppTextStyles.headingLarge),
              const SizedBox(height: 4),
              Text('Weather, reminders & more',
                  style: AppTextStyles.bodyMuted),
              const SizedBox(height: 18),

              WeatherCard(
                weather: weather,
                onRefresh: () => ref.invalidate(weatherProvider),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Reminders', style: AppTextStyles.heading),
                  TextButton.icon(
                    onPressed: () => _addReminder(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (reminders.isEmpty)
                _EmptyReminders(onAdd: () => _addReminder(context, ref))
              else
                ...reminders.map(
                  (r) => ReminderTile(
                    reminder: r,
                    onToggle: () =>
                        ref.read(remindersProvider.notifier).toggleDone(r),
                    onDelete: () =>
                        ref.read(remindersProvider.notifier).remove(r),
                  ),
                ),
              const SizedBox(height: 24),

              FunCard(
                content: fun,
                onLoad: (type) =>
                    ref.read(funContentProvider.notifier).load(type),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addReminder(BuildContext context, WidgetRef ref) async {
    // Ask for notification permission up front (no-op if already granted).
    await ref.read(notificationServiceProvider).requestPermissions();
    if (!context.mounted) return;

    final result = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDarkAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddReminderSheet(),
    );

    if (result != null) {
      await ref
          .read(remindersProvider.notifier)
          .add(result.title, result.time);
    }
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.notifications_none_rounded,
              color: AppColors.textMuted, size: 36),
          const SizedBox(height: 8),
          Text('No reminders yet',
              style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text("I'll nudge you right on time. Add your first one!",
              style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onAdd, child: const Text('Add reminder')),
        ],
      ),
    );
  }
}

class _ReminderDraft {
  final String title;
  final DateTime time;
  const _ReminderDraft(this.title, this.time);
}

class _AddReminderSheet extends StatefulWidget {
  const _AddReminderSheet();

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final TextEditingController _title = TextEditingController();
  DateTime _time = DateTime.now().add(const Duration(hours: 1));
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _time.isBefore(now) ? now : _time,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (time == null || !mounted) return;
    setState(() {
      _time =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give your reminder a title.');
      return;
    }
    if (_time.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future.');
      return;
    }
    Navigator.pop(context, _ReminderDraft(title, _time));
  }

  @override
  Widget build(BuildContext context) {
    final df = MaterialLocalizations.of(context);
    final dateLabel =
        '${df.formatMediumDate(_time)} • ${df.formatTimeOfDay(TimeOfDay.fromDateTime(_time))}';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New reminder', style: AppTextStyles.heading),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            style: AppTextStyles.body,
            decoration: const InputDecoration(hintText: 'What should I remind you about?'),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.primarySoft),
                  const SizedBox(width: 12),
                  Expanded(child: Text(dateLabel, style: AppTextStyles.body)),
                  const Icon(Icons.edit_calendar_rounded,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: AppTextStyles.label.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Set reminder'),
            ),
          ),
        ],
      ),
    );
  }
}
