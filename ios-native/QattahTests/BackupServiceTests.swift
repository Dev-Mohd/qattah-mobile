import XCTest
import GRDB
import QattahKit
@testable import Qattah

final class BackupServiceTests: XCTestCase {
    func testExportThenRestoreRoundTrips() async throws {
        let database = try AppDatabase.inMemory()
        let store = QattahStore(database: database)
        let list = QattahList(name: "الدوام")
        try await store.saveList(list)
        let a = Member(listId: list.id, name: "أحمد", openingBalance: Money(riyals: 7.5))
        try await store.saveMember(a)
        try await store.saveMeal(MealRecord(listId: list.id, mealTypeId: nil, mealName: "فطور",
                                            day: Day("2026-11-01")!, totalAmount: Money(riyals: 12)), attendees: [a])
        try await store.savePayment(Payment(listId: list.id, memberId: a.id, memberName: a.name,
                                            amount: Money(riyals: 4), paidOn: Day("2026-11-02")!))

        let service = BackupService(database: database)
        let url = try service.export()
        let summary = try service.inspect(url)
        XCTAssertEqual(summary.lists, 1)
        XCTAssertEqual(summary.meals, 1)

        try service.deleteAllData()
        XCTAssertNil(try store.snapshot(listId: list.id))

        try service.restore(from: url)
        let snapshot = try XCTUnwrap(try store.snapshot(listId: list.id))
        XCTAssertEqual(snapshot.balances.members.first?.net, Money(riyals: 15.5))
        XCTAssertEqual(snapshot.payments.first?.paidOn, Day("2026-11-02"))
    }

    /// A backup written by the Flutter app (no `paid_on`, extra unknown keys).
    func testRestoresFlutterBackup() throws {
        let json = """
        {"app":"qattah","version":1,"exported_at":"2026-05-12T10:00:00.000",
         "tables":{
          "lists":[{"id":"l1","name":"قديمة","color":"#2563EB","created_at":"2026-05-01T08:00:00.000","updated_at":"2026-05-01T08:00:00.000"}],
          "members":[{"id":"m1","list_id":"l1","name":"سعد","emoji":"👤","is_active":1,"opening_balance":0.0,"is_default_attendee":1,"sync_status":"local","created_at":"","updated_at":""}],
          "meal_types":[],
          "records":[{"id":"r1","list_id":"l1","meal_name":"غداء","date":"2026-05-02","total_amount":20.0,"per_person":20.0,"note":"","created_at":"","updated_at":"","future_column":"ignored"}],
          "record_participants":[{"id":"p1","record_id":"r1","member_id":"m1","member_name":"سعد","share":20.0}],
          "payments":[{"id":"x1","list_id":"l1","member_id":"m1","member_name":"سعد","amount":5,"note":"","created_at":"2026-05-03T09:00:00.000","updated_at":"2026-05-03T09:00:00.000"}]
         }}
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("flutter-backup-test.json")
        try Data(json.utf8).write(to: url)

        let database = try AppDatabase.inMemory()
        try BackupService(database: database).restore(from: url)

        let snapshot = try XCTUnwrap(try QattahStore(database: database).snapshot(listId: "l1"))
        XCTAssertEqual(snapshot.balances.members.first?.net, Money(riyals: 15))
        XCTAssertEqual(snapshot.payments.first?.paidOn, Day("2026-05-03"))
    }

    func testRejectsOtherFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-qattah.json")
        try Data(#"{"app":"other","tables":{}}"#.utf8).write(to: url)
        XCTAssertThrowsError(try BackupService(database: try AppDatabase.inMemory()).inspect(url))
    }
}
