import SwiftUI
import Observation
import QattahKit

/// User preferences, stored in UserDefaults.
///
/// On first launch after updating from the Flutter version, values saved by
/// `shared_preferences` (keys prefixed with "flutter.") are copied over, so
/// the theme, reminder time and onboarding state are kept.
@MainActor
@Observable
final class AppSettings {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "تلقائي"
            case .light: "فاتح"
            case .dark: "داكن"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    private enum Key {
        static let appearance = "appearance"
        static let reminderEnabled = "dailyReminderEnabled"
        static let reminderHour = "dailyReminderHour"
        static let reminderMinute = "dailyReminderMinute"
        static let onboardingSeen = "onboardingSeen"
        static let migratedFromFlutter = "migratedFlutterPreferences"
        static let paymentDetails = "paymentDetails"
    }

    private let defaults: UserDefaults

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    var reminderEnabled: Bool {
        didSet { defaults.set(reminderEnabled, forKey: Key.reminderEnabled) }
    }

    var reminderHour: Int {
        didSet { defaults.set(reminderHour, forKey: Key.reminderHour) }
    }

    var reminderMinute: Int {
        didSet { defaults.set(reminderMinute, forKey: Key.reminderMinute) }
    }

    var onboardingSeen: Bool {
        didSet { defaults.set(onboardingSeen, forKey: Key.onboardingSeen) }
    }

    /// The organizer's bank / wallet details, added to reminders.
    var paymentDetails: PaymentDetails {
        didSet {
            if let data = try? JSONEncoder().encode(paymentDetails) {
                defaults.set(data, forKey: Key.paymentDetails)
            }
        }
    }

    /// The reminder time as a Date today (for DatePicker binding).
    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = parts.hour ?? 12
            reminderMinute = parts.minute ?? 0
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateFlutterPreferences(defaults)

        appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        reminderEnabled = defaults.bool(forKey: Key.reminderEnabled)
        reminderHour = defaults.object(forKey: Key.reminderHour) as? Int ?? 12
        reminderMinute = defaults.object(forKey: Key.reminderMinute) as? Int ?? 0
        onboardingSeen = defaults.bool(forKey: Key.onboardingSeen)
        paymentDetails = defaults.data(forKey: Key.paymentDetails)
            .flatMap { try? JSONDecoder().decode(PaymentDetails.self, from: $0) } ?? PaymentDetails()
    }

    private static func migrateFlutterPreferences(_ defaults: UserDefaults) {
        guard !defaults.bool(forKey: Key.migratedFromFlutter) else { return }
        defer { defaults.set(true, forKey: Key.migratedFromFlutter) }

        if let mode = defaults.string(forKey: "flutter.theme_mode"),
           let appearance = Appearance(rawValue: mode) {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
        }
        if let enabled = defaults.object(forKey: "flutter.daily_reminder_enabled") as? Bool {
            defaults.set(enabled, forKey: Key.reminderEnabled)
        }
        if let hour = defaults.object(forKey: "flutter.daily_reminder_hour") as? Int {
            defaults.set(hour, forKey: Key.reminderHour)
        }
        if let minute = defaults.object(forKey: "flutter.daily_reminder_minute") as? Int {
            defaults.set(minute, forKey: Key.reminderMinute)
        }
        if defaults.bool(forKey: "flutter.onboarding_seen_v1") {
            defaults.set(true, forKey: Key.onboardingSeen)
        }
    }
}
