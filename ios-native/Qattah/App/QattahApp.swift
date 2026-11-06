import SwiftUI
import GRDB
import QattahKit

@main
struct QattahApp: App {
    @State private var boot = AppBootstrap()
    @State private var settings = AppSettings()
    @State private var showSplash = true
    @State private var toaster = Toaster()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    switch boot.state {
                    case .loading:
                        Color.clear
                    case .ready(let store):
                        RootView(splashFinished: !showSplash)
                            .environment(\.store, store)
                    case .failed(let error):
                        RecoveryView(error: error) { boot.startFresh() }
                    }
                }

                ToastOverlay()

                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
                    .zIndex(1)
                }
            }
            .environment(settings)
            .environment(toaster)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .preferredColorScheme(settings.appearance.colorScheme)
            .tint(.qattahAccent)
            .task { boot.start() }
        }
    }
}

/// Home screen plus app-wide behaviour: onboarding, and keeping the daily
/// reminder, the widget and Siri suggestions in sync with the data.
private struct RootView: View {
    /// Onboarding waits for the launch animation to finish.
    let splashFinished: Bool
    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var summaries: [ListSummary] = []

    var body: some View {
        ListsView()
            .fullScreenCover(isPresented: Binding(
                get: { splashFinished && !settings.onboardingSeen },
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
                        WidgetSync.refresh(store: store)
                        QattahShortcuts.updateAppShortcutParameters()
                    }
                } catch {
                    // Observation only fails if the database is closed; nothing to do.
                }
            }
            .onChange(of: settings.reminderEnabled) { _, _ in Task { await refreshReminders() } }
            .onChange(of: settings.reminderHour) { _, _ in Task { await refreshReminders() } }
            .onChange(of: settings.reminderMinute) { _, _ in Task { await refreshReminders() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        // Meals tapped in the widget are saved now.
                        await WidgetSync.applyPendingLogs(store: store)
                        await refreshReminders()
                    }
                }
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
            state = .ready(QattahStore(database: try AppDatabase.shared()))
        } catch {
            state = .failed(error)
        }
    }

    /// Keeps the unreadable file aside (never deletes it) and starts with an empty database.
    func startFresh() {
        do {
            try AppDatabase.moveUnreadableDatabaseAside()
            AppDatabase.resetShared()
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
