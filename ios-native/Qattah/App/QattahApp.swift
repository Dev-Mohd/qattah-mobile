import SwiftUI

@main
struct QattahApp: App {
    @State private var boot = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            Group {
                switch boot.state {
                case .loading:
                    ProgressView()
                case .ready(let store):
                    ListsView()
                        .environment(\.store, store)
                case .failed(let error):
                    RecoveryView(error: error) { boot.startFresh() }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .tint(.qattahAccent)
            .task { boot.start() }
        }
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
