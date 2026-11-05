import Foundation
import GRDB
import QattahKit

/// Everything the UI needs about one list, fetched in a single read.
struct ListSnapshot: Sendable {
    var list: QattahList
    var members: [Member]
    var mealTypes: [MealType]
    var records: [MealRecord]
    var participants: [Participant]
    var payments: [Payment]

    var balances: ListBalances {
        BalanceCalculator.balances(members: members, records: records,
                                   participants: participants, payments: payments)
    }

    func participants(of record: MealRecord) -> [Participant] {
        participants.filter { $0.recordId == record.id }
    }
}

/// A list with its headline numbers, for the home screen.
struct ListSummary: Identifiable, Sendable {
    var list: QattahList
    var memberCount: Int
    var totalOwed: Money
    var lastMealDay: Day?
    var id: String { list.id }
}

/// Reads and writes app data.
///
/// The UI observes data with `ValueObservation`, so every screen refreshes
/// automatically after any write — no manual cache invalidation (the source
/// of stale balances in the Flutter version).
final class QattahStore: Sendable {
    let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Observation

    func observeSummaries() -> AsyncValueObservation<[ListSummary]> {
        ValueObservation
            .tracking { db in try Self.fetchSummaries(db) }
            .values(in: database.writer)
    }

    func observeList(id: String) -> AsyncValueObservation<ListSnapshot?> {
        ValueObservation
            .tracking { db in try Self.fetchSnapshot(db, listId: id) }
            .values(in: database.writer)
    }

    func snapshot(listId: String) throws -> ListSnapshot? {
        try database.writer.read { db in try Self.fetchSnapshot(db, listId: listId) }
    }

    static func fetchSummaries(_ db: Database) throws -> [ListSummary] {
        let lists = try Row.fetchAll(db, sql: """
            SELECT * FROM lists WHERE is_archived = 0 ORDER BY created_at
            """).map(QattahList.init(row:))
        return try lists.map { list in
            guard let snapshot = try fetchSnapshot(db, listId: list.id) else {
                return ListSummary(list: list, memberCount: 0, totalOwed: .zero, lastMealDay: nil)
            }
            return ListSummary(list: list,
                               memberCount: snapshot.members.filter(\.isActive).count,
                               totalOwed: snapshot.balances.totalOwed,
                               lastMealDay: snapshot.records.map(\.day).max())
        }
    }

    static func fetchSnapshot(_ db: Database, listId: String) throws -> ListSnapshot? {
        guard let listRow = try Row.fetchOne(db, sql: "SELECT * FROM lists WHERE id = ?", arguments: [listId]) else {
            return nil
        }
        let members = try Row.fetchAll(db, sql: """
            SELECT * FROM members WHERE list_id = ? ORDER BY created_at
            """, arguments: [listId]).map(Member.init(row:))
        let mealTypes = try Row.fetchAll(db, sql: """
            SELECT * FROM meal_types WHERE list_id = ? ORDER BY created_at
            """, arguments: [listId]).map(MealType.init(row:))
        let records = try Row.fetchAll(db, sql: """
            SELECT * FROM records WHERE list_id = ? ORDER BY date DESC, created_at DESC
            """, arguments: [listId]).map(MealRecord.init(row:))
        let participants = try Row.fetchAll(db, sql: """
            SELECT rp.* FROM record_participants rp
            JOIN records r ON r.id = rp.record_id
            WHERE r.list_id = ?
            """, arguments: [listId]).map(Participant.init(row:))
        let payments = try Row.fetchAll(db, sql: """
            SELECT * FROM payments WHERE list_id = ? ORDER BY paid_on DESC, created_at DESC
            """, arguments: [listId]).map(Payment.init(row:))

        return ListSnapshot(list: QattahList(row: listRow), members: members, mealTypes: mealTypes,
                            records: records, participants: participants, payments: payments)
    }

    // MARK: - Lists

    func saveList(_ list: QattahList) async throws {
        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO lists (id, name, color, icon, is_archived, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  name = excluded.name, color = excluded.color, icon = excluded.icon,
                  is_archived = excluded.is_archived, updated_at = excluded.updated_at
                """, arguments: [list.id, list.name, list.color, list.icon, list.isArchived ? 1 : 0,
                                 DBDate.string(list.createdAt), DBDate.string(.now)])
        }
    }

    func deleteList(id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM lists WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Members

    func saveMember(_ member: Member) async throws {
        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO members (id, list_id, name, emoji, is_active, opening_balance,
                                     is_default_attendee, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  name = excluded.name, emoji = excluded.emoji, is_active = excluded.is_active,
                  opening_balance = excluded.opening_balance,
                  is_default_attendee = excluded.is_default_attendee,
                  updated_at = excluded.updated_at
                """, arguments: [member.id, member.listId, member.name, member.emoji,
                                 member.isActive ? 1 : 0, member.openingBalance.riyals,
                                 member.isDefaultAttendee ? 1 : 0,
                                 DBDate.string(member.createdAt), DBDate.string(.now)])
        }
    }

    /// Members with history are deactivated instead of deleted, so their
    /// meals and payments keep counting in the balances.
    func removeMember(_ member: Member) async throws {
        try await database.writer.write { db in
            let hasHistory = try Bool.fetchOne(db, sql: """
                SELECT EXISTS(SELECT 1 FROM record_participants WHERE member_id = ?)
                    OR EXISTS(SELECT 1 FROM payments WHERE member_id = ?)
                """, arguments: [member.id, member.id]) ?? false
            if hasHistory || !member.openingBalance.isZero {
                try db.execute(sql: "UPDATE members SET is_active = 0, is_default_attendee = 0, updated_at = ? WHERE id = ?",
                               arguments: [DBDate.string(.now), member.id])
            } else {
                try db.execute(sql: "DELETE FROM members WHERE id = ?", arguments: [member.id])
            }
        }
    }

    // MARK: - Meal types

    func saveMealType(_ mealType: MealType) async throws {
        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO meal_types (id, list_id, name, default_price, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  name = excluded.name, default_price = excluded.default_price,
                  updated_at = excluded.updated_at
                """, arguments: [mealType.id, mealType.listId, mealType.name, mealType.defaultPrice.riyals,
                                 DBDate.string(mealType.createdAt), DBDate.string(.now)])
        }
    }

    func deleteMealType(id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM meal_types WHERE id = ?", arguments: [id])
        }
    }

    // MARK: - Meals

    /// Saves a meal and splits its total among the attendees, to the halala.
    /// Passing an existing `record.id` replaces that meal (edit).
    func saveMeal(_ record: MealRecord, attendees: [Member]) async throws {
        let shares = SplitCalculator.split(record.totalAmount, among: attendees.map(\.id))
        let perPerson = SplitCalculator.perPerson(record.totalAmount, attendeeCount: attendees.count)
        let names = Dictionary(uniqueKeysWithValues: attendees.map { ($0.id, $0.name) })
        let now = DBDate.string(.now)

        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO records (id, list_id, meal_type_id, meal_name, date, total_amount, total_price,
                                     per_person, price_per_person, note, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  meal_type_id = excluded.meal_type_id, meal_name = excluded.meal_name,
                  date = excluded.date, total_amount = excluded.total_amount,
                  total_price = excluded.total_price, per_person = excluded.per_person,
                  price_per_person = excluded.price_per_person, note = excluded.note,
                  updated_at = excluded.updated_at
                """, arguments: [record.id, record.listId, record.mealTypeId, record.mealName,
                                 record.day.description, record.totalAmount.riyals, record.totalAmount.riyals,
                                 perPerson.riyals, perPerson.riyals, record.note,
                                 DBDate.string(record.createdAt), now])

            try db.execute(sql: "DELETE FROM record_participants WHERE record_id = ?", arguments: [record.id])
            for (memberId, share) in shares {
                try db.execute(sql: """
                    INSERT INTO record_participants (id, record_id, member_id, member_name, share,
                                                     share_amount, is_present, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
                    """, arguments: [UUID().uuidString.lowercased(), record.id, memberId,
                                     names[memberId] ?? "عضو", share.riyals, share.riyals, now, now])
            }
        }
    }

    func deleteMeal(id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM records WHERE id = ?", arguments: [id])
        }
    }

    /// Re-inserts a deleted meal exactly as it was (for "undo").
    func restoreMeal(_ record: MealRecord, participants: [Participant]) async throws {
        let perPerson = SplitCalculator.perPerson(record.totalAmount, attendeeCount: participants.count).riyals
        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT OR IGNORE INTO records (id, list_id, meal_type_id, meal_name, date, total_amount,
                                               total_price, per_person, price_per_person, note, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [record.id, record.listId, record.mealTypeId, record.mealName,
                                 record.day.description, record.totalAmount.riyals, record.totalAmount.riyals,
                                 perPerson, perPerson, record.note, DBDate.string(record.createdAt),
                                 DBDate.string(record.updatedAt)])
            for p in participants {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO record_participants (id, record_id, member_id, member_name, share,
                                                               share_amount, is_present, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
                    """, arguments: [p.id, p.recordId, p.memberId, p.memberName, p.share.riyals, p.share.riyals,
                                     DBDate.string(.now), DBDate.string(.now)])
            }
        }
    }

    // MARK: - Payments

    func savePayment(_ payment: Payment) async throws {
        try await database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO payments (id, list_id, member_id, member_name, amount, note, paid_on,
                                      created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  amount = excluded.amount, note = excluded.note, paid_on = excluded.paid_on,
                  updated_at = excluded.updated_at
                """, arguments: [payment.id, payment.listId, payment.memberId, payment.memberName,
                                 payment.amount.riyals, payment.note, payment.paidOn.description,
                                 DBDate.string(payment.createdAt), DBDate.string(.now)])
        }
    }

    func deletePayment(id: String) async throws {
        try await database.writer.write { db in
            try db.execute(sql: "DELETE FROM payments WHERE id = ?", arguments: [id])
        }
    }
}
