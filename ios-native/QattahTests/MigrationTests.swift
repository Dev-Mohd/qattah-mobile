import XCTest
import GRDB
import QattahKit
@testable import Qattah

final class MigrationTests: XCTestCase {
    /// A database exactly as the Flutter app left it must migrate to the
    /// latest schema without losing or changing any data.
    func testFlutterDatabaseMigratesToLatestSchema() throws {
        let queue = try DatabaseQueue()
        try queue.write { db in
            try FlutterSchema.create(db)
            try db.execute(sql: """
                INSERT INTO lists (id, name, color, created_at, updated_at)
                VALUES ('l1', 'الدوام', '#2563EB', '2026-05-01T08:00:00.000', '2026-05-01T08:00:00.000');
                INSERT INTO members (id, list_id, name, opening_balance, created_at, updated_at)
                VALUES ('m1', 'l1', 'أحمد', 12.5, '2026-05-01T08:00:00.000', '2026-05-01T08:00:00.000');
                INSERT INTO records (id, list_id, meal_name, date, total_amount, per_person, created_at, updated_at)
                VALUES ('r1', 'l1', 'فطور', '2026-05-02', 40, 40, '2026-05-02T08:00:00.000', '2026-05-02T08:00:00.000');
                INSERT INTO record_participants (id, record_id, member_id, member_name, share)
                VALUES ('p1', 'r1', 'm1', 'أحمد', 40);
                INSERT INTO payments (id, list_id, member_id, member_name, amount, created_at, updated_at)
                VALUES ('pay1', 'l1', 'm1', 'أحمد', 20, '2026-05-03T09:30:00.000', '2026-05-03T09:30:00.000');
                """)
        }

        let database = try AppDatabase(queue)

        try database.writer.read { db in
            let expected: [String: [String]] = [
                "payments": ["paid_on", "record_id", "batch_id"],
                "records": ["split_mode", "extras", "treat_member_id"],
                "members": ["phone"],
                "lists": ["organizer_member_id"],
                "record_participants": ["guest_name"],
            ]
            for (table, columns) in expected {
                let existing = try db.columns(in: table).map(\.name)
                for column in columns {
                    XCTAssertTrue(existing.contains(column), "\(table).\(column) is missing")
                }
            }
            XCTAssertTrue(try db.tableExists("menu_items"))
            XCTAssertTrue(try db.tableExists("record_items"))
        }

        let snapshot = try XCTUnwrap(try QattahStore(database: database).snapshot(listId: "l1"))
        let record = try XCTUnwrap(snapshot.records.first)
        XCTAssertEqual(record.splitMode, .equal)
        XCTAssertNil(record.treatMemberId)
        let payment = try XCTUnwrap(snapshot.payments.first)
        XCTAssertEqual(payment.paidOn, Day("2026-05-03"))
        XCTAssertNil(payment.batchId)
        XCTAssertNil(payment.recordId)
        // 12.50 opening + 40 meal − 20 paid
        XCTAssertEqual(snapshot.balances.members.first?.net, Money(riyals: 32.5))
    }

    func testMigratingTwiceIsHarmless() throws {
        let queue = try DatabaseQueue()
        _ = try AppDatabase(queue)
        XCTAssertNoThrow(try AppDatabase(queue))
    }

    func testBatchAndTreatRoundTrip() async throws {
        let store = QattahStore(database: try AppDatabase.inMemory())
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أحمد")
        let b = Member(listId: list.id, name: "سعد")
        try await store.saveMember(a)
        try await store.saveMember(b)

        // One top-up of 100 for both members, recorded as a batch.
        let batch = UUID().uuidString.lowercased()
        try await store.savePayments([a, b].map {
            Payment(listId: list.id, memberId: $0.id, memberName: $0.name, amount: Money(riyals: 100),
                    note: "تعبئة نوفمبر", paidOn: Day("2026-11-01")!, batchId: batch)
        })
        try await store.saveMeal(MealRecord(listId: list.id, mealTypeId: nil, mealName: "غداء",
                                            day: Day("2026-11-02")!, totalAmount: Money(riyals: 60),
                                            treatMemberId: a.id), attendees: [a, b])

        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.payments.filter { $0.batchId == batch }.count, 2)
        XCTAssertEqual(snapshot.records.first?.treatMemberId, a.id)
        XCTAssertEqual(snapshot.records.first?.isTreat, true)

        // Removing the member who treated keeps the meal (ON DELETE SET NULL is not triggered:
        // members with history are deactivated, not deleted).
        try await store.removeMember(a)
        let after = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(after.records.first?.treatMemberId, a.id)
    }
}

final class PotThresholdTests: XCTestCase {
    func testThresholdDefaultsAndUpdatesWithoutTouchingOtherFields() async throws {
        let store = QattahStore(database: try AppDatabase.inMemory())
        var list = QattahList(name: "الدوام", icon: "☕️")
        try await store.saveList(list)
        var snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.list.potThreshold, Money(riyals: 50))

        try await store.setPotThreshold(Money(riyals: 80), listId: list.id)

        // Saving an older copy of the list (e.g. after a rename) keeps the new threshold.
        list.name = "فطور الدوام"
        try await store.saveList(list)
        snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.list.potThreshold, Money(riyals: 80))
        XCTAssertEqual(snapshot.list.name, "فطور الدوام")
        XCTAssertEqual(snapshot.list.icon, "☕️")
    }
}

final class TreatTests: XCTestCase {
    func testTreatChargesHostAndFallsBackWhenHostAbsent() async throws {
        let store = QattahStore(database: try AppDatabase.inMemory())
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أحمد")
        let b = Member(listId: list.id, name: "سعد")
        let c = Member(listId: list.id, name: "فهد")
        for member in [a, b, c] { try await store.saveMember(member) }

        var meal = MealRecord(listId: list.id, mealTypeId: nil, mealName: "غداء", day: Day("2026-11-10")!,
                              totalAmount: Money(riyals: 90), treatMemberId: b.id)
        try await store.saveMeal(meal, attendees: [a, b, c])

        var snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        var net = Dictionary(uniqueKeysWithValues: snapshot.balances.members.map { ($0.id, $0.net) })
        XCTAssertEqual(net[b.id], Money(riyals: 90))
        XCTAssertEqual(net[a.id], .zero)
        XCTAssertEqual(snapshot.participants.count, 3)          // everyone is recorded as attending
        XCTAssertEqual(snapshot.records.first?.treatMemberId, b.id)

        // Editing so the host no longer attends turns it back into a normal split.
        meal.totalAmount = Money(riyals: 60)
        try await store.saveMeal(meal, attendees: [a, c])
        snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        net = Dictionary(uniqueKeysWithValues: snapshot.balances.members.map { ($0.id, $0.net) })
        XCTAssertNil(snapshot.records.first?.treatMemberId)
        XCTAssertEqual(net[a.id], Money(riyals: 30))
        XCTAssertEqual(net[c.id], Money(riyals: 30))
        XCTAssertEqual(net[b.id], .zero)
    }
}
