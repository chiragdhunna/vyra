import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/app_logger.dart';

/// Wraps `flutter_local_notifications` for Vyra's reminder system.
///
/// Handles initialization, timezone setup (so scheduled reminders fire at the
/// right local time, including across DST), permission requests, and
/// scheduling / cancelling notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'vyra_reminders',
    'Vyra Reminders',
    channelDescription: 'Reminders and nudges from Vyra',
    importance: Importance.max,
    priority: Priority.high,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone));
    } catch (e) {
      AppLogger.w('Could not resolve local timezone, defaulting to UTC: $e',
          tag: 'Notify');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);
    _ready = true;
    AppLogger.d('NotificationService ready', tag: 'Notify');
  }

  /// Requests notification permission (Android 13+ and iOS). Returns true if
  /// granted (or if not applicable on the platform).
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  /// Shows a notification immediately.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(id, title, body, _details);
  }

  /// Schedules a one-off reminder at [when] (local time).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    // Guard against scheduling in the past.
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      AppLogger.w('Skipping reminder "$title" — time is in the past',
          tag: 'Notify');
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    AppLogger.d('Scheduled reminder #$id at $scheduled', tag: 'Notify');
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
