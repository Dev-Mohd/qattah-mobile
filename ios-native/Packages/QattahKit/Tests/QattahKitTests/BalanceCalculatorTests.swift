import XCTest
@testable import QattahKit

final class BalanceCalculatorTests: XCTestCase {
    private let list = "list"

    private func member(_ id: String, _ name: String, opening: Double = 0) -> Member {
        Member(id: id, listId: list, name: name, openingBalance: Money(riyals: opening))
    }

    private func meal(_ id: String, _ total: Double, day: String = "2026-11-01") -> MealRecord {
        MealRecord(id: id, listId: list, mealTypeId: nil, mealName: "فطور", day: Day(day)!,
                   totalAmount: Money(riyals: total))
    }

    private func share(_ record: String, _ memberId: String?, _ name: String, _ amount: Double) -> Participant {
        Participant(recordId: record, memberId: memberId, memberName: name, share: Money(riyals: amount))
    }

    private func payment(_ memberId: String?, _ name: String, _ amount: Double) -> Payment {
        Payment(listId: list, memberId: memberId, memberName: name, amount: Money(riyals: amount),
                paidOn: Day("2026-11-02")!)
    }

    func testBasicBalances() {
        let members = [member("a", "أحمد", opening: 10), member("b", "سعد")]
        let records = [meal("r1", 60)]
        let participants = [share("r1", "a", "أحمد", 30), share("r1", "b", "سعد", 30)]
        let payments = [payment("b", "سعد", 50)]

        let result = BalanceCalculator.balances(members: members, records: records,
                                                participants: participants, payments: payments)
        let a = result.members.first { $0.id == "a" }!
        let b = result.members.first { $0.id == "b" }!

        XCTAssertEqual(a.net, Money(riyals: 40))
        XCTAssertEqual(a.status, .owes)
        XCTAssertEqual(a.mealCount, 1)
        XCTAssertEqual(b.net, Money(riyals: -20))
        XCTAssertEqual(b.status, .credit)
        XCTAssertEqual(result.totalOwed, Money(riyals: 40))
        XCTAssertEqual(result.totalCredit, Money(riyals: 20))
        XCTAssertEqual(result.totalSpent, Money(riyals: 60))
    }

    func testSameNameIsNotDoubleCounted() {
        // Two members called "محمد". The Flutter version added shares by name
        // on top of shares by id, so each got the other's shares too.
        let members = [member("m1", "محمد"), member("m2", "محمد")]
        let participants = [share("r1", "m1", "محمد", 20), share("r1", "m2", "محمد", 20)]
        let result = BalanceCalculator.balances(members: members, records: [meal("r1", 40)],
                                                participants: participants, payments: [])
        XCTAssertEqual(result.members.map(\.spent), [Money(riyals: 20), Money(riyals: 20)])
        XCTAssertTrue(result.unassigned.isEmpty)
    }

    func testLegacyShareWithoutIdMatchesUniqueName() {
        let members = [member("a", "أحمد")]
        let participants = [share("r1", nil, "أحمد", 15)]
        let result = BalanceCalculator.balances(members: members, records: [meal("r1", 15)],
                                                participants: participants, payments: [])
        XCTAssertEqual(result.members[0].spent, Money(riyals: 15))
    }

    func testAmbiguousOrDeletedSharesAreReportedNotGuessed() {
        let members = [member("m1", "محمد"), member("m2", "محمد")]
        let participants = [share("r1", nil, "محمد", 10), share("r1", nil, "خالد", 5)]
        let result = BalanceCalculator.balances(members: members, records: [meal("r1", 15)],
                                                participants: participants, payments: [])
        XCTAssertEqual(result.members.map(\.spent), [.zero, .zero])
        XCTAssertEqual(Set(result.unassigned.map(\.memberName)), ["محمد", "خالد"])
        XCTAssertEqual(result.totalSpent, Money(riyals: 15))
    }

    func testSharesOfDeletedRecordsAreIgnored() {
        let members = [member("a", "أحمد")]
        let participants = [share("gone", "a", "أحمد", 99)]
        let result = BalanceCalculator.balances(members: members, records: [],
                                                participants: participants, payments: [])
        XCTAssertEqual(result.members[0].spent, .zero)
    }

    func testShareMessage() {
        let members = [member("a", "أحمد"), member("b", "سعد"), member("c", "فهد")]
        let participants = [share("r1", "a", "أحمد", 30), share("r1", "b", "سعد", 30),
                            share("r1", "c", "فهد", 30)]
        let payments = [payment("b", "سعد", 50), payment("c", "فهد", 30)]
        let balances = BalanceCalculator.balances(members: members, records: [meal("r1", 90)],
                                                  participants: participants, payments: payments)
        let text = ShareMessageBuilder.balancesMessage(listName: "الدوام", balances: balances,
                                                       asOf: Day("2026-11-05")!)
        XCTAssertTrue(text.contains("🍽️ قطّة الدوام"))
        XCTAssertTrue(text.contains("• أحمد: 30 ر.س"))
        XCTAssertTrue(text.contains("• سعد: 20 ر.س"))
        XCTAssertTrue(text.contains("✅ مسدّدين: فهد"))
        XCTAssertTrue(text.contains("المجموع المطلوب: 30 ر.س"))
    }
}

final class AttendanceSuggesterTests: XCTestCase {
    func testUsesLastAttendeesOfSameMealType() {
        let breakfast = MealType(id: "t1", listId: "l", name: "فطور", defaultPrice: Money(riyals: 10))
        let members = [
            Member(id: "a", listId: "l", name: "أ"),
            Member(id: "b", listId: "l", name: "ب"),
            Member(id: "c", listId: "l", name: "ج", isDefaultAttendee: false),
        ]
        let older = MealRecord(id: "r1", listId: "l", mealTypeId: "t1", mealName: "فطور",
                               day: Day("2026-11-01")!, totalAmount: Money(riyals: 30))
        let latest = MealRecord(id: "r2", listId: "l", mealTypeId: "t1", mealName: "فطور",
                                day: Day("2026-11-03")!, totalAmount: Money(riyals: 20))
        let participants = [
            Participant(recordId: "r1", memberId: "a", memberName: "أ", share: Money(riyals: 10)),
            Participant(recordId: "r2", memberId: "b", memberName: "ب", share: Money(riyals: 10)),
            Participant(recordId: "r2", memberId: "c", memberName: "ج", share: Money(riyals: 10)),
        ]

        let suggestion = AttendanceSuggester.suggest(mealType: breakfast, members: members,
                                                     records: [older, latest], participants: participants)
        XCTAssertEqual(suggestion.attendeeIds, ["b", "c"])
        XCTAssertEqual(suggestion.reason, .sameAsLastTime(Day("2026-11-03")!))
        XCTAssertEqual(suggestion.total, Money(riyals: 20))
    }

    func testFallsBackToDefaultAttendees() {
        let members = [
            Member(id: "a", listId: "l", name: "أ"),
            Member(id: "b", listId: "l", name: "ب", isDefaultAttendee: false),
            Member(id: "c", listId: "l", name: "ج", isActive: false),
        ]
        let suggestion = AttendanceSuggester.suggest(mealType: nil, members: members, records: [], participants: [])
        XCTAssertEqual(suggestion.attendeeIds, ["a"])
        XCTAssertEqual(suggestion.reason, .defaultAttendees)
        XCTAssertNil(suggestion.total)
    }
}
