import SwiftUI
import GRDB
import QattahKit

@main
struct QattahApp: App {
    @State private var boot = AppBootstrap()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            Group {
                switch boot.state {
                case .loading:
                    ProgressView()
                case .ready(let store):
                    RootView()
                        .environment(\.store, store)
                case .failed(let error):
                    RecoveryView(error: error) { boot.startFresh() }
                }
            }
            .environment(settings)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(.qattahAccent)
            .task { boot.start() }
        }
    }
}

/// Home screen plus app-wide behaviour: onboarding and keeping the daily
/// reminder in sync with the data.
private struct RootView: View {
    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var summaries: [ListSummary] = []

    var body: some View {
        ListsView()
            .fullScreenCover(isPresented: Binding(
                get: { !settings.onboardingSeen },
                set: { if !$0 { settings.onboardingSeen = true } }
            )) {
                OnboardingView { settings.onboardingSeen = true }
            }
            .task {
                // Every data change (meal logged, payment…) re-plans the reminders.
                do {
                    for try await value in store.observeSummaries() {
                        summaries = value
                        await refreshReminders()
                    }
                } catch {
                    // Observation only fails if the database is closed; nothing to do.
                }
            }
            .onChange(of: settings.reminderEnabled) { _, _ in Task { await refreshReminders() } }
            .onChange(of: settings.reminderHour) { _, _ in Task { await refreshReminders() } }
            .onChange(of: settings.reminderMinute) { _, _ in Task { await refreshReminders() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshReminders() } }
            }
    }

    private func refreshReminders() async {
        let today = Day.today()
        await ReminderScheduler.refresh(
            enabled: settings.reminderEnabled,
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
            mealLoggedToday: summaries.contains { $0.lastMealDay == today },
            totalOwed: summaries.map(\.totalOwed).sum()
        )
    }
}

/// Opens the database once at launch and exposes the result to the UI.
@MainActor
@Observable
final class AppBootstrap {
    enum Phase {
        case loading
        case ready(QattahStore)
        case failed(Error)
    }

    private(set) var state: Phase = .loading

    func start() {
        guard case .loading = state else { return }
        do {
            state = .ready(QattahStore(database: try AppDatabase.openOnDisk()))
        } catch {
            state = .failed(error)
        }
    }

    /// Keeps the unreadable file aside (never deletes it) and starts with an empty database.
    func startFresh() {
        do {
            try AppDatabase.moveUnreadableDatabaseAside()
            state = .loading
            start()
        } catch {
            state = .failed(error)
        }
    }
}

private struct StoreKey: EnvironmentKey {
    // Previews get an empty in-memory database.
    static let defaultValue: QattahStore = {
        // swiftlint:disable:next force_try
        QattahStore(database: try! AppDatabase.inMemory())
    }()
}

extension EnvironmentValues {
    var store: QattahStore {
        get { self[StoreKey.self] }
        set { self[StoreKey.self] = newValue }
    }
}
