import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/service_providers.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/storage/storage_service.dart';
import '../data/models/fun_content.dart';
import '../data/models/reminder.dart';
import '../data/models/weather.dart';
import '../data/services/fun_content_api.dart';
import '../data/services/weather_api.dart';

// --- API handles ---
final weatherApiProvider = Provider<WeatherApi>((ref) => WeatherApi.instance);
final funContentApiProvider =
    Provider<FunContentApi>((ref) => FunContentApi.instance);

// --- Weather (re-fetched on demand by invalidating) ---
final weatherProvider = FutureProvider.autoDispose<Weather>((ref) {
  return ref.read(weatherApiProvider).fetchForCurrentLocation();
});

// --- Reminders ---
final remindersProvider =
    StateNotifierProvider<RemindersController, List<Reminder>>(
  (ref) => RemindersController(ref),
);

class RemindersController extends StateNotifier<List<Reminder>> {
  RemindersController(this._ref) : super(const []) {
    _load();
  }

  final Ref _ref;
  static const String _key = 'list';

  StorageService get _storage => _ref.read(storageServiceProvider);
  NotificationService get _notify => _ref.read(notificationServiceProvider);

  void _load() {
    final raw = _storage.reminderBox.get(_key);
    if (raw is List) {
      final list = raw.whereType<Map>().map(Reminder.fromMap).toList();
      list.sort((a, b) => a.time.compareTo(b.time));
      state = list;
    }
  }

  Future<void> add(String title, DateTime time) async {
    final id = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
    final reminder = Reminder(id: id, title: title.trim(), time: time);
    final next = [...state, reminder]
      ..sort((a, b) => a.time.compareTo(b.time));
    state = next;
    await _notify.schedule(
      id: id,
      title: 'Vyra reminder',
      body: reminder.title,
      when: time,
    );
    _persist();
  }

  Future<void> remove(Reminder reminder) async {
    state = state.where((r) => r.id != reminder.id).toList();
    await _notify.cancel(reminder.id);
    _persist();
  }

  Future<void> toggleDone(Reminder reminder) async {
    state = [
      for (final r in state)
        if (r.id == reminder.id) r.copyWith(done: !r.done) else r,
    ];
    if (!reminder.done) {
      // Marking complete: cancel any pending notification.
      await _notify.cancel(reminder.id);
    }
    _persist();
  }

  void _persist() {
    _storage.reminderBox
        .put(_key, state.map((r) => r.toMap()).toList(growable: false));
  }
}

// --- Fun content (quotes / jokes / facts) ---
final funContentProvider =
    StateNotifierProvider<FunContentNotifier, AsyncValue<FunContent?>>(
  (ref) => FunContentNotifier(ref),
);

class FunContentNotifier extends StateNotifier<AsyncValue<FunContent?>> {
  FunContentNotifier(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> load(FunType type) async {
    state = const AsyncLoading();
    try {
      final content = await _ref.read(funContentApiProvider).fetch(type);
      if (mounted) state = AsyncData(content);
    } catch (e, st) {
      if (mounted) state = AsyncError(e, st);
    }
  }
}
