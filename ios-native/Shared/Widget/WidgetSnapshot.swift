import Foundation
import QattahKit

// Shared between the app and the widget extension.
//
// Why not let the widget open the database? The database is encrypted with
// SQLCipher; holding a lock on an encrypted SQLite file in a shared App Group
// container can get the app killed by iOS (0xDEAD10CC). So:
//   • the app writes a small summary (`WidgetSnapshot`) for the widget, and
//   • widget buttons append a `PendingMealLog`, which the app saves into the
//     database the next time it runs (it also runs in the background when a
//     Siri shortcut is used).

/// What the widget displays for one list.
struct WidgetList: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var colorHex: String
    var totalOwedHalalas: Int
    /// Up to three biggest debts: (name, halalas).
    var topDebtors: [Debtor]
    /// Day of the latest meal ("yyyy-MM-dd").
    var lastMealDay: String?
    /// What one tap on "log" would save, if the app can guess it.
    var quickLog: QuickLog?

    struct Debtor: Codable, Hashable, Sendable {
        var name: String
        var halalas: Int
    }

    struct QuickLog: Codable, Hashable, Sendable {
        var mealTypeId: String?
        var mealName: String
        var attendeeIds: [String]
        var totalHalalas: Int
    }

    var totalOwed: Money { Money(halalas: totalOwedHalalas) }

    func loggedToday(today: Day = .today()) -> Bool {
        lastMealDay == today.description
    }
}

struct WidgetSnapshot: Codable, Sendable {
    var lists: [WidgetList]
    var updatedAt: Date

    static let empty = WidgetSnapshot(lists: [], updatedAt: .distantPast)
}

/// A meal logged from the widget, waiting for the app to save it.
struct PendingMealLog: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var listId: String
    var mealTypeId: String?
    var mealName: String
    var day: String
    var attendeeIds: [String]
    var totalHalalas: Int
    var createdAt: Date
}

/// Reads and writes the shared files in the App Group container.
enum SharedStore {
    /// The App Group id comes from Info.plist (different for Debug/Release).
    static var groupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "QattahAppGroup") as? String
    }

    private static var directory: URL? {
        guard let id = groupIdentifier else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    private static var snapshotURL: URL? { directory?.appendingPathComponent("widget-snapshot.json") }
    private static var pendingURL: URL? { directory?.appendingPathComponent("pending-meals.json") }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: Snapshot

    static func readSnapshot() -> WidgetSnapshot {
        guard let url = snapshotURL, let data = try? coordinatedRead(url),
              let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    static func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL, let data = try? encoder.encode(snapshot) else { return }
        try? coordinatedWrite(data, to: url)
    }

    // MARK: Pending meals

    static func readPending() -> [PendingMealLog] {
        guard let url = pendingURL, let data = try? coordinatedRead(url) else { return [] }
        return (try? decoder.decode([PendingMealLog].self, from: data)) ?? []
    }

    static func appendPending(_ log: PendingMealLog) {
        var all = readPending()
        all.append(log)
        writePending(all)
    }

    /// Removes the given logs (after the app saved them).
    static func removePending(ids: Set<String>) {
        writePending(readPending().filter { !ids.contains($0.id) })
    }

    private static func writePending(_ logs: [PendingMealLog]) {
        guard let url = pendingURL, let data = try? encoder.encode(logs) else { return }
        try? coordinatedWrite(data, to: url)
    }

    // MARK: File coordination (app and widget run in different processes)

    private static func coordinatedRead(_ url: URL) throws -> Data {
        var result: Data?
        var readError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            do { result = try Data(contentsOf: url) } catch { readError = error }
        }
        if let error = coordinationError ?? readError { throw error }
        return result ?? Data()
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var writeError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
            do {
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError { throw error }
    }
}
