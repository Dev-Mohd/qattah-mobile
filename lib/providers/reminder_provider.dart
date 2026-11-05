import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notification_service.dart';
import 'smart_notifications_provider.dart';

class ReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

class ReminderNotifier extends StateNotifier<ReminderSettings> {
  final Ref _ref;

  ReminderNotifier(this._ref)
      : super(const ReminderSettings(enabled: false, hour: 12, minute: 0)) {
    _load();
  }

  static const _enabledKey = 'daily_reminder_enabled';
  static const _hourKey = 'daily_reminder_hour';
  static const _minuteKey = 'daily_reminder_minute';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 12,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
    state = settings;

    if (settings.enabled) {
      await _schedule(settings);
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final next = state.copyWith(enabled: enabled);
    if (enabled) {
      final allowed = await NotificationService().requestPermissions();
      if (!allowed) return false;
      await _schedule(next);
    } else {
      await NotificationService().cancelDailyReminder();
    }
    await _save(next);
    state = next;
    return true;
  }

  Future<bool> setTime(int hour, int minute) async {
    final next = state.copyWith(hour: hour, minute: minute);
    if (next.enabled) {
      final allowed = await NotificationService().requestPermissions();
      if (!allowed) return false;
      await _schedule(next);
    }
    await _save(next);
    state = next;
    return true;
  }

  Future<void> _schedule(ReminderSettings settings) {
    final smart = _ref.read(smartNotificationsProvider);
    final body = smart.enabled && smart.includeInDailyReminder
        ? 'افتح قطه وراجع التنبيهات الذكية عن السداد والمتبقي.'
        : 'لا تنسَ تسجيل وجبة اليوم إذا كانت هناك مشاركة.';

    return NotificationService().scheduleDailyReminder(
      hour: settings.hour,
      minute: settings.minute,
      title: 'تذكير قطه',
      body: body,
    );
  }

  Future<void> _save(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_hourKey, settings.hour);
    await prefs.setInt(_minuteKey, settings.minute);
  }
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, ReminderSettings>(
  (ref) => ReminderNotifier(ref),
);
