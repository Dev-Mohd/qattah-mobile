import Foundation
import GRDB

/// JSON backup, compatible with the Flutter version's format:
///
/// ```json
/// { "app": "qattah", "version": 1, "exported_at": "…",
///   "tables": { "lists": [ {…row…} ], "members": [ … ], … } }
/// ```
///
/// Backups made by the Flutter app can be imported here, and vice versa
/// (unknown columns are ignored on import).
struct BackupService {
    let database: AppDatabase

    static let formatVersion = 1

    enum BackupError: LocalizedError {
        case notAQattahBackup
        case invalidTable(String)
        case unreadableFile

        var errorDescription: String? {
            switch self {
            case .notAQattahBackup: "هذا الملف ليس نسخة احتياطية من تطبيق قطّه"
            case .invalidTable(let name): "بيانات جدول \(name) غير صحيحة"
            case .unreadableFile: "تعذّرت قراءة الملف"
            }
        }
    }

    struct Summary {
        let lists: Int
        let members: Int
        let meals: Int
        let payments: Int
    }

    // MARK: - Export

    /// Writes a backup file to the temporary directory and returns its URL.
    func export() throws -> URL {
        let tables: [String: [[String: Any]]] = try database.writer.read { db in
            var result: [String: [[String: Any]]] = [:]
            for table in AppDatabase.allTables {
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(table)")
                result[table] = rows.map(Self.jsonObject(from:))
            }
            return result
        }

        let payload: [String: Any] = [
            "app": "qattah",
            "version": Self.formatVersion,
            "exported_at": DBDate.string(.now),
            "tables": tables,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.removeItem(at: directory) // don't leave old copies around
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = DBDate.string(.now).prefix(16).replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("qattah-backup-\(stamp).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: - Import

    /// Reads a backup without changing anything, to show what it contains.
    func inspect(_ url: URL) throws -> Summary {
        let tables = try readTables(url)
        return Summary(lists: tables["lists"]?.count ?? 0,
                       members: tables["members"]?.count ?? 0,
                       meals: tables["records"]?.count ?? 0,
                       payments: tables["payments"]?.count ?? 0)
    }

    /// Replaces all data with the backup's content (in one transaction:
    /// if anything fails, nothing changes).
    func restore(from url: URL) throws {
        let tables = try readTables(url)

        try database.writer.write { db in
            for table in AppDatabase.allTables.reversed() {
                try db.execute(sql: "DELETE FROM \(table)")
            }
            for table in AppDatabase.allTables {
                let known = Set(try db.columns(in: table).map(\.name))
                for row in tables[table] ?? [] {
                    let columns = row.keys.filter(known.contains).sorted()
                    guard columns.contains("id") else { continue }
                    let names = columns.map { "\"\($0)\"" }.joined(separator: ", ")
                    let marks = Array(repeating: "?", count: columns.count).joined(separator: ", ")
                    let values: [(any DatabaseValueConvertible)?] = columns.map { Self.databaseValue(row[$0]) }
                    try db.execute(sql: "INSERT OR REPLACE INTO \(table) (\(names)) VALUES (\(marks))",
                                   arguments: StatementArguments(values))
                }
            }
            // Flutter backups have no payment date: use the creation date.
            try db.execute(sql: """
                UPDATE payments SET paid_on = substr(created_at, 1, 10)
                WHERE paid_on IS NULL OR paid_on = ''
                """)
        }
    }

    func deleteAllData() throws {
        try database.writer.write { db in
            for table in AppDatabase.allTables.reversed() {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
    }

    // MARK: - Helpers

    private func readTables(_ url: URL) throws -> [String: [[String: Any]]] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            throw BackupError.unreadableFile
        }
        guard let root = object as? [String: Any],
              root["app"] as? String == "qattah",
              let tables = root["tables"] as? [String: Any] else {
            throw BackupError.notAQattahBackup
        }

        var result: [String: [[String: Any]]] = [:]
        for table in AppDatabase.allTables {
            guard let value = tables[table] else { continue }
            guard let rows = value as? [[String: Any]] else { throw BackupError.invalidTable(table) }
            result[table] = rows
        }
        return result
    }

    private static func jsonObject(from row: Row) -> [String: Any] {
        var object: [String: Any] = [:]
        for (column, value) in row {
            switch value.storage {
            case .null: object[column] = NSNull()
            case .int64(let int): object[column] = int
            case .double(let double): object[column] = double
            case .string(let string): object[column] = string
            case .blob(let data): object[column] = data.base64EncodedString()
            }
        }
        return object
    }

    private static func databaseValue(_ value: Any?) -> (any DatabaseValueConvertible)? {
        switch value {
        case nil, is NSNull: return nil
        case let number as NSNumber:
            // JSON numbers: keep integers as integers (flags, counts), others as REAL.
            if CFNumberIsFloatType(number) { return number.doubleValue }
            return number.int64Value
        case let string as String: return string
        default: return nil
        }
    }
}
