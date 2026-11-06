import Foundation
import GRDB

/// Opens the encrypted database created by the Flutter version
/// (`Documents/qattah_secure.db`) and keeps its schema up to date.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    static let fileName = "qattah_secure.db"
    static let legacyPlainFileName = "qattah.db"

    enum OpenError: LocalizedError {
        /// The database file exists but its key is not in the Keychain
        /// (typically: restored onto a new iPhone from a Flutter-era backup).
        case missingKey
        /// The key in the Keychain does not decrypt the file.
        case wrongKey

        var errorDescription: String? {
            switch self {
            case .missingKey, .wrongKey:
                return "تعذّر فتح بياناتك المشفّرة على هذا الجهاز. يمكنك استعادة نسخة احتياطية أو البدء من جديد."
            }
        }
    }

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    private static let sharedLock = NSLock()
    nonisolated(unsafe) private static var sharedInstance: AppDatabase?

    /// The single on-disk database for this process (used by the UI and by
    /// Siri intents, which may run while the app is in the background).
    static func shared() throws -> AppDatabase {
        sharedLock.lock()
        defer { sharedLock.unlock() }
        if let sharedInstance { return sharedInstance }
        let database = try openOnDisk()
        sharedInstance = database
        return database
    }

    /// Forgets the shared instance (after the file was moved aside).
    static func resetShared() {
        sharedLock.lock()
        sharedInstance = nil
        sharedLock.unlock()
    }

    /// The app's on-disk database.
    static func openOnDisk(fileManager: FileManager = .default) throws -> AppDatabase {
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
        let url = documents.appendingPathComponent(fileName)
        let keyStore = DatabaseKeyStore()

        let key: String
        if let existing = try keyStore.readKey() {
            key = existing
            try? keyStore.makeKeyTransferableWithBackups()
        } else if fileManager.fileExists(atPath: url.path) {
            throw OpenError.missingKey
        } else {
            key = try keyStore.createKey()
        }

        var config = Configuration()
        config.label = "Qattah"
        config.prepareDatabase { db in
            try db.usePassphrase(key)
        }

        let queue: DatabaseQueue
        do {
            queue = try DatabaseQueue(path: url.path, configuration: config)
            // SQLCipher only notices a wrong key on the first real read.
            _ = try queue.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master") }
        } catch let error as DatabaseError where error.resultCode == .SQLITE_NOTADB {
            throw OpenError.wrongKey
        }

        let database = try AppDatabase(queue)
        try LegacyFiles.importUnencryptedDatabaseIfNeeded(in: documents, into: database)
        LegacyFiles.removePlaintextLeftovers(in: documents)
        return database
    }

    /// Moves the unreadable database aside and starts fresh (used from the
    /// recovery screen, after the user confirms). Nothing is deleted.
    static func moveUnreadableDatabaseAside(fileManager: FileManager = .default) throws {
        let documents = try fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
        let url = documents.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        try fileManager.moveItem(at: url, to: documents.appendingPathComponent("qattah_unreadable_\(stamp).db"))
    }

    /// An empty in-memory database for previews and tests.
    static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    // MARK: - Schema

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Matches the schema the Flutter version created (and repaired on every
        // launch). Safe on existing databases: everything is "IF NOT EXISTS".
        migrator.registerMigration("v1_flutter_baseline") { db in
            try FlutterSchema.create(db)
        }

        // Payments get a real "paid on" day so a payment can be back-dated
        // (Flutter grouped payments by the moment they were typed in).
        migrator.registerMigration("v2_payment_paid_on") { db in
            let paymentColumns = try db.columns(in: "payments").map(\.name)
            if !paymentColumns.contains("paid_on") {
                try db.execute(sql: "ALTER TABLE payments ADD COLUMN paid_on TEXT")
            }
            try db.execute(sql: """
                UPDATE payments SET paid_on = substr(created_at, 1, 10)
                WHERE paid_on IS NULL OR paid_on = ''
                """)
        }

        // Itemized meals ("each pays for what they ordered"), the list's
        // restaurant menu, and members' phone numbers for WhatsApp reminders.
        // Additive only: the Flutter app ignores the new tables/columns.
        migrator.registerMigration("v3_items_menu_phone") { db in
            func addColumn(_ table: String, _ column: String, _ definition: String) throws {
                if try !db.columns(in: table).map(\.name).contains(column) {
                    try db.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
                }
            }
            try addColumn("members", "phone", "TEXT")
            try addColumn("records", "split_mode", "TEXT NOT NULL DEFAULT 'equal'")
            try addColumn("records", "extras", "REAL NOT NULL DEFAULT 0")

            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS menu_items (
                  id TEXT PRIMARY KEY NOT NULL,
                  list_id TEXT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
                  name TEXT NOT NULL,
                  price REAL NOT NULL DEFAULT 0,
                  created_at TEXT NOT NULL DEFAULT '',
                  updated_at TEXT NOT NULL DEFAULT ''
                );
                CREATE INDEX IF NOT EXISTS idx_menu_items_list ON menu_items(list_id);
                CREATE TABLE IF NOT EXISTS record_items (
                  id TEXT PRIMARY KEY NOT NULL,
                  record_id TEXT NOT NULL REFERENCES records(id) ON DELETE CASCADE,
                  member_id TEXT REFERENCES members(id) ON DELETE SET NULL,
                  item_name TEXT NOT NULL,
                  unit_price REAL NOT NULL DEFAULT 0,
                  quantity INTEGER NOT NULL DEFAULT 1,
                  created_at TEXT NOT NULL DEFAULT ''
                );
                CREATE INDEX IF NOT EXISTS idx_record_items_record ON record_items(record_id);
                """)
        }

        // One-time guests (their share is charged to the host) and payments
        // linked to a meal ("who paid the restaurant").
        migrator.registerMigration("v4_guests_bill_payer") { db in
            if try !db.columns(in: "record_participants").map(\.name).contains("guest_name") {
                try db.execute(sql: "ALTER TABLE record_participants ADD COLUMN guest_name TEXT")
            }
            if try !db.columns(in: "payments").map(\.name).contains("record_id") {
                try db.execute(sql: """
                    ALTER TABLE payments ADD COLUMN record_id TEXT REFERENCES records(id) ON DELETE CASCADE
                    """)
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_payments_record ON payments(record_id)")
        }

        // Which member runs the pot (for the settlement plan).
        migrator.registerMigration("v5_list_organizer") { db in
            if try !db.columns(in: "lists").map(\.name).contains("organizer_member_id") {
                try db.execute(sql: "ALTER TABLE lists ADD COLUMN organizer_member_id TEXT")
            }
        }

        return migrator
    }

    /// Every table, in insertion order (parents first) — used by backups.
    static let allTables = ["lists", "members", "meal_types", "menu_items", "records",
                            "record_participants", "record_items", "payments"]
}

/// The original Flutter schema, column for column.
enum FlutterSchema {
    static let tables = ["lists", "members", "meal_types", "records", "record_participants", "payments"]

    static func create(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS lists (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              color TEXT NOT NULL DEFAULT '#2563EB',
              icon TEXT,
              is_archived INTEGER NOT NULL DEFAULT 0,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS members (
              id TEXT PRIMARY KEY NOT NULL,
              list_id TEXT NOT NULL,
              name TEXT NOT NULL,
              emoji TEXT NOT NULL DEFAULT '👤',
              is_active INTEGER NOT NULL DEFAULT 1,
              opening_balance REAL NOT NULL DEFAULT 0,
              is_default_attendee INTEGER NOT NULL DEFAULT 1,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS meal_types (
              id TEXT PRIMARY KEY NOT NULL,
              list_id TEXT NOT NULL,
              name TEXT NOT NULL,
              default_price REAL NOT NULL DEFAULT 0,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS records (
              id TEXT PRIMARY KEY NOT NULL,
              list_id TEXT NOT NULL,
              meal_type_id TEXT,
              meal_name TEXT NOT NULL DEFAULT 'وجبة',
              date TEXT NOT NULL,
              total_amount REAL NOT NULL DEFAULT 0,
              total_price REAL NOT NULL DEFAULT 0,
              per_person REAL NOT NULL DEFAULT 0,
              price_per_person REAL NOT NULL DEFAULT 0,
              note TEXT NOT NULL DEFAULT '',
              notes TEXT,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
              FOREIGN KEY (meal_type_id) REFERENCES meal_types(id) ON DELETE SET NULL
            );
            CREATE TABLE IF NOT EXISTS record_participants (
              id TEXT PRIMARY KEY NOT NULL,
              record_id TEXT NOT NULL,
              member_id TEXT,
              member_name TEXT NOT NULL DEFAULT 'عضو',
              share REAL NOT NULL DEFAULT 0,
              is_present INTEGER NOT NULL DEFAULT 1,
              share_amount REAL NOT NULL DEFAULT 0,
              is_paid INTEGER NOT NULL DEFAULT 0,
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE,
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
            );
            CREATE TABLE IF NOT EXISTS payments (
              id TEXT PRIMARY KEY NOT NULL,
              list_id TEXT NOT NULL,
              member_id TEXT,
              member_name TEXT NOT NULL,
              amount REAL NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              sync_status TEXT NOT NULL DEFAULT 'local',
              created_at TEXT NOT NULL DEFAULT '',
              updated_at TEXT NOT NULL DEFAULT '',
              FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
              FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
            );
            CREATE INDEX IF NOT EXISTS idx_records_list_date ON records(list_id, date);
            CREATE INDEX IF NOT EXISTS idx_participants_record ON record_participants(record_id);
            CREATE INDEX IF NOT EXISTS idx_participants_member ON record_participants(member_id);
            CREATE INDEX IF NOT EXISTS idx_payments_list ON payments(list_id);
            CREATE INDEX IF NOT EXISTS idx_payments_member ON payments(member_id);
            """)

        // Very old Flutter databases may miss columns added later. The Flutter
        // app repaired them on each launch; do the same once here.
        let columns: [(String, String, String)] = [
            ("lists", "color", "TEXT NOT NULL DEFAULT '#2563EB'"),
            ("lists", "icon", "TEXT"),
            ("lists", "is_archived", "INTEGER NOT NULL DEFAULT 0"),
            ("members", "emoji", "TEXT NOT NULL DEFAULT '👤'"),
            ("members", "is_active", "INTEGER NOT NULL DEFAULT 1"),
            ("members", "opening_balance", "REAL NOT NULL DEFAULT 0"),
            ("members", "is_default_attendee", "INTEGER NOT NULL DEFAULT 1"),
            ("meal_types", "default_price", "REAL NOT NULL DEFAULT 0"),
            ("records", "meal_type_id", "TEXT"),
            ("records", "meal_name", "TEXT NOT NULL DEFAULT 'وجبة'"),
            ("records", "total_amount", "REAL NOT NULL DEFAULT 0"),
            ("records", "per_person", "REAL NOT NULL DEFAULT 0"),
            ("records", "note", "TEXT NOT NULL DEFAULT ''"),
            ("record_participants", "member_name", "TEXT NOT NULL DEFAULT 'عضو'"),
            ("record_participants", "share", "REAL NOT NULL DEFAULT 0"),
        ]
        for (table, column, definition) in columns {
            let existing = try db.columns(in: table).map(\.name)
            if !existing.contains(column) {
                try db.execute(sql: "ALTER TABLE \(table) ADD COLUMN \(column) \(definition)")
            }
        }
    }
}

/// Files left behind by the Flutter version.
enum LegacyFiles {
    /// If a pre-encryption database (`qattah.db`) still holds data that the
    /// encrypted one does not, copy it over — then delete the plaintext file.
    static func importUnencryptedDatabaseIfNeeded(in directory: URL, into database: AppDatabase) throws {
        let url = directory.appendingPathComponent(AppDatabase.legacyPlainFileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // No passphrase → SQLCipher reads it as a plain SQLite file.
        var config = Configuration()
        config.readonly = true
        let legacy = try DatabaseQueue(path: url.path, configuration: config)

        let legacyRows = try legacy.read { try rowCount($0) }
        let currentRows = try database.writer.read { try rowCount($0) }

        if legacyRows > currentRows {
            let snapshot: [String: [Row]] = try legacy.read { db in
                var result: [String: [Row]] = [:]
                for table in FlutterSchema.tables {
                    guard try db.tableExists(table) else { continue }
                    result[table] = try Row.fetchAll(db, sql: "SELECT * FROM \(table)")
                }
                return result
            }
            try database.writer.write { db in
                for table in FlutterSchema.tables.reversed() {
                    try db.execute(sql: "DELETE FROM \(table)")
                }
                for table in FlutterSchema.tables {
                    let target = Set(try db.columns(in: table).map(\.name))
                    for row in snapshot[table] ?? [] {
                        let columns = row.columnNames.filter(target.contains)
                        guard !columns.isEmpty else { continue }
                        let names = columns.map { "\"\($0)\"" }.joined(separator: ", ")
                        let marks = Array(repeating: "?", count: columns.count).joined(separator: ", ")
                        let values: [(any DatabaseValueConvertible)?] = columns.map { row[$0] as DatabaseValue }
                        try db.execute(sql: "INSERT OR REPLACE INTO \(table) (\(names)) VALUES (\(marks))",
                                       arguments: StatementArguments(values))
                    }
                }
            }
        }

        try legacy.close()
        removeFileAndSidecars(url)
    }

    /// The Flutter migration renamed the plaintext database to
    /// `qattah_plain_backup_*.db` and kept it forever, unencrypted. Also
    /// remove the encrypted pre-restore copies that were never cleaned up.
    static func removePlaintextLeftovers(in directory: URL) {
        let prefixes = ["qattah_plain_backup_", "qattah_secure_before_restore_"]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let name = file.lastPathComponent
            guard prefixes.contains(where: { name.hasPrefix($0) }) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func removeFileAndSidecars(_ url: URL) {
        for suffix in ["", "-journal", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    private static func rowCount(_ db: Database) throws -> Int {
        var total = 0
        for table in FlutterSchema.tables {
            guard try db.tableExists(table) else { continue }
            total += try Int.fetchOne(db, sql: "SELECT count(*) FROM \(table)") ?? 0
        }
        return total
    }
}
