import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartNotificationsSettings {
  final bool enabled;
  final bool includeInDailyReminder;

  const SmartNotificationsSettings({
    required this.enabled,
    required this.includeInDailyReminder,
  });

  SmartNotificationsSettings copyWith({
    bool? enabled,
    bool? includeInDailyReminder,
  }) {
    return SmartNotificationsSettings(
      enabled: enabled ?? this.enabled,
      includeInDailyReminder:
          includeInDailyReminder ?? this.includeInDailyReminder,
    );
  }
}

class SmartNotificationsNotifier
    extends StateNotifier<SmartNotificationsSettings> {
  SmartNotificationsNotifier()
      : super(
          const SmartNotificationsSettings(
            enabled: true,
            includeInDailyReminder: false,
          ),
        ) {
    _load();
  }

  static const _enabledKey = 'smart_notifications_enabled';
  static const _includeDailyKey = 'smart_notifications_include_daily';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = SmartNotificationsSettings(
      enabled: prefs.getBool(_enabledKey) ?? true,
      includeInDailyReminder: prefs.getBool(_includeDailyKey) ?? false,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final next = state.copyWith(enabled: enabled);
    await _save(next);
    state = next;
  }

  Future<void> setIncludeInDailyReminder(bool include) async {
    final next = state.copyWith(includeInDailyReminder: include);
    await _save(next);
    state = next;
  }

  Future<void> _save(SmartNotificationsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setBool(_includeDailyKey, settings.includeInDailyReminder);
  }
}

final smartNotificationsProvider = StateNotifierProvider<
    SmartNotificationsNotifier, SmartNotificationsSettings>(
  (ref) => SmartNotificationsNotifier(),
);
