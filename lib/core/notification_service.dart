import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final location = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(location.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    await init();

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidAllowed = await android?.requestNotificationsPermission();

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosAllowed = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macos = _notifications.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final macosAllowed = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidAllowed ?? iosAllowed ?? macosAllowed ?? true;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await cancelDailyReminder();
    await _schedule(
      hour: hour,
      minute: minute,
      title: title,
      body: body,
      mode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required AndroidScheduleMode mode,
  }) {
    return _notifications.zonedSchedule(
      0,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          channelDescription: 'Reminds you to log meals',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(0);
  }
}
