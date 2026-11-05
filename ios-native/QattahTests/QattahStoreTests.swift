import XCTest
import GRDB
import QattahKit
@testable import Qattah

final class QattahStoreTests: XCTestCase {
    private func makeStore() throws -> QattahStore {
        QattahStore(database: try AppDatabase.inMemory())
    }

    func testSaveMealSplitsExactlyAndBalancesUpdate() async throws {
        let store = try makeStore()
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)

        let members = ["أحمد", "سعد", "فهد"].map { Member(listId: list.id, name: $0) }
        for member in members { try await store.saveMember(member) }

        let meal = MealRecord(listId: list.id, mealTypeId: nil, mealName: "فطور",
                              day: Day("2026-11-05")!, totalAmount: Money(riyals: 100))
        try await store.saveMeal(meal, attendees: members)

        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.participants.map(\.share).sum(), Money(riyals: 100))
        XCTAssertEqual(snapshot.balances.totalOwed, Money(riyals: 100))
    }

    func testEditingMealReplacesParticipants() async throws {
        let store = try makeStore()
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أ")
        let b = Member(listId: list.id, name: "ب")
        try await store.saveMember(a)
        try await store.saveMember(b)

        var meal = MealRecord(listId: list.id, mealTypeId: nil, mealName: "غداء",
                              day: .today(), totalAmount: Money(riyals: 40))
        try await store.saveMeal(meal, attendees: [a, b])
        meal.totalAmount = Money(riyals: 30)
        try await store.saveMeal(meal, attendees: [a])

        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(snapshot.participants.count, 1)
        XCTAssertEqual(snapshot.balances.members.first { $0.id == a.id }?.net, Money(riyals: 30))
        XCTAssertEqual(snapshot.balances.members.first { $0.id == b.id }?.net, .zero)
    }

    func testRemovingMemberWithHistoryKeepsTheirBalance() async throws {
        let store = try makeStore()
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أ")
        try await store.saveMember(a)
        try await store.saveMeal(MealRecord(listId: list.id, mealTypeId: nil, mealName: "فطور",
                                            day: .today(), totalAmount: Money(riyals: 15)), attendees: [a])

        try await store.removeMember(a)

        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        let row = try XCTUnwrap(snapshot.balances.members.first { $0.id == a.id })
        XCTAssertFalse(row.member.isActive)
        XCTAssertEqual(row.net, Money(riyals: 15))
    }

    func testBackdatedPaymentKeepsItsDay() async throws {
        let store = try makeStore()
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أ")
        try await store.saveMember(a)
        try await store.savePayment(Payment(listId: list.id, memberId: a.id, memberName: a.name,
                                            amount: Money(riyals: 20), paidOn: Day("2026-10-31")!))

        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.payments.first?.paidOn, Day("2026-10-31"))
    }

    /// Rows written by the Flutter app (no `paid_on`, Dart date strings,
    /// legacy columns) must read back correctly.
    func testReadsFlutterStyleRows() throws {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            try db.execute(sql: """
                INSERT INTO lists (id, name, color, created_at, updated_at)
                VALUES ('l1', 'قديمة', '#2563EB', '2026-05-10T09:15:00.123456', '2026-05-10T09:15:00.123456');
                INSERT INTO members (id, list_id, name, opening_balance, created_at, updated_at)
                VALUES ('m1', 'l1', 'أحمد', 5.5, '2026-05-10T09:15:00.123456', '');
                INSERT INTO records (id, list_id, meal_name, date, total_amount, per_person, created_at)
                VALUES ('r1', 'l1', 'فطور', '2026-05-11', 33.33, 33.33, '2026-05-11T08:00:00.000');
                INSERT INTO record_participants (id, record_id, member_id, member_name, share)
                VALUES ('p1', 'r1', NULL, 'أحمد', 33.33);
                INSERT INTO payments (id, list_id, member_id, member_name, amount, created_at, updated_at)
                VALUES ('pay1', 'l1', 'm1', 'أحمد', 10, '2026-05-20T12:00:00.000', '2026-05-20T12:00:00.000');
                UPDATE payments SET paid_on = NULL;
                """)
        }
        let snapshot = try XCTUnwrap(try QattahStore(database: database).snapshot(listId: "l1"))
        XCTAssertEqual(snapshot.payments.first?.paidOn, Day("2026-05-20"))
        // 5.50 opening + 33.33 legacy share matched by unique name − 10 paid
        XCTAssertEqual(snapshot.balances.members.first?.net, Money(riyals: 28.83))
    }
}
