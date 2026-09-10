import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {
      // Some Android versions do not support this permission request.
    }
  }

  Future<void> scheduleDailyMissYouNotification(int level) async {
    const androidDetails = AndroidNotificationDetails(
      'boombug_reminders',
      'BoomBug reminders',
      channelDescription: 'Reminders to return to BoomBug',
      importance: Importance.max,
      priority: Priority.high,
    );

    try {
      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        20,
        0,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: 23,
        title: 'BoomBug misses you',
        body: 'We miss you! You are on level $level.',
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Notification delivery is optional and should not interrupt gameplay.
    }
  }

  Future<void> cancelDailyMissYouNotification() async {
    try {
      await _plugin.cancel(id: 23);
    } catch (_) {
      // Ignore platform notification errors.
    }
  }
}
