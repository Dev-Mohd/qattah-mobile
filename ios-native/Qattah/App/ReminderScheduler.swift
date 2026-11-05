import Foundation
import UserNotifications
import QattahKit

/// Daily "log today's meal" reminder.
///
/// Smarter than the Flutter version's fixed repeating notification:
/// reminders are scheduled one per day for the next two weeks, and **today's
/// reminder is skipped once a meal has been logged today**. The text also
/// mentions how much is still owed across all lists.
enum ReminderScheduler {
    private static let prefix = "qattah.daily."
    private static let daysAhead = 14

    /// Asks for permission if needed. Returns whether notifications are allowed.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Re-plans all reminders. Call at launch, when returning to the app,
    /// after logging a meal and when the settings change.
    static func refresh(enabled: Bool, hour: Int, minute: Int,
                        mealLoggedToday: Bool, totalOwed: Money) async {
        let center = UNUserNotificationCenter.current()

        // Remove ours, plus the Flutter plugin's old repeating reminder (id "0").
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) || $0 == "0" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        guard enabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        let now = Date.now
        let startOffset = mealLoggedToday ? 1 : 0

        for offset in startOffset..<(startOffset + daysAhead) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "تذكير قطّه"
            content.body = offset == 0 && totalOwed.isPositive
                ? "لم تسجّل وجبة اليوم بعد • المستحق حالياً \(MoneyFormatter.plain(totalOwed))"
                : "لا تنسَ تسجيل وجبة اليوم إذا كانت هناك مشاركة"
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = prefix + Day(fire, calendar: calendar).description
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
