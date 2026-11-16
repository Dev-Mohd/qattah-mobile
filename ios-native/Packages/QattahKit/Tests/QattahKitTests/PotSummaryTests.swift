import XCTest
@testable import QattahKit

final class PotSummaryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        return calendar
    }()

    private func balance(_ id: String, paid: Double, spent: Double, active: Bool = true) -> MemberBalance {
        MemberBalance(member: Member(id: id, listId: "l", name: id, isActive: active), openingBalance: .zero,
                      spent: Money(riyals: spent), paid: Money(riyals: paid), mealCount: 1)
    }

    private func meal(_ day: String, _ total: Double) -> MealRecord {
        MealRecord(listId: "l", mealTypeId: nil, mealName: "فطور", day: Day(day)!, totalAmount: Money(riyals: total))
    }

    func testBalanceDaysLeftAndTopUps() {
        // a: 100 in, 30 spent → 70 credit. b: 100 in, 80 spent → 20 credit. c: nothing in, 10 spent → owes 10.
        let balances = ListBalances(members: [balance("a", paid: 100, spent: 30), balance("b", paid: 100, spent: 80),
                                              balance("c", paid: 0, spent: 10)], unassigned: [])
        // 140 spent in the last 14 days (one meal outside the window is ignored).
        let records = [meal("2026-11-15", 70), meal("2026-11-03", 70), meal("2026-11-02", 500)]

        let pot = PotCalculator.summary(balances: balances, records: records, threshold: Money(riyals: 50),
                                        today: Day("2026-11-16")!, calendar: calendar)

        XCTAssertEqual(pot.balance, Money(riyals: 80))                 // 200 in − 120 spent
        XCTAssertEqual(pot.averageDailySpending, Money(riyals: 10))    // 140 / 14
        XCTAssertEqual(pot.daysLeft, 8)
        XCTAssertEqual(pot.members.map(\.id), ["c", "b", "a"])         // lowest credit first
        XCTAssertEqual(pot.membersNeedingTopUp.map(\.id), ["c", "b"])
        XCTAssertEqual(pot.members.first?.credit, Money(riyals: -10))
    }

    func testEmptyOrOverdrawnPotHasNoDaysLeft() {
        let overdrawn = ListBalances(members: [balance("a", paid: 0, spent: 40)], unassigned: [])
        let pot = PotCalculator.summary(balances: overdrawn, records: [meal("2026-11-16", 40)],
                                        threshold: Money(riyals: 50), today: Day("2026-11-16")!, calendar: calendar)
        XCTAssertEqual(pot.balance, Money(riyals: -40))
        XCTAssertNil(pot.daysLeft)

        let idle = ListBalances(members: [balance("a", paid: 100, spent: 0)], unassigned: [])
        XCTAssertNil(PotCalculator.summary(balances: idle, records: [], threshold: .zero,
                                           today: Day("2026-11-16")!, calendar: calendar).daysLeft)
    }

    func testInactiveMembersAreNotAskedToTopUp() {
        let balances = ListBalances(members: [balance("gone", paid: 0, spent: 15, active: false)], unassigned: [])
        let pot = PotCalculator.summary(balances: balances, records: [], threshold: Money(riyals: 50),
                                        today: Day("2026-11-16")!, calendar: calendar)
        XCTAssertEqual(pot.members.count, 1)            // still listed: they owe money
        XCTAssertTrue(pot.membersNeedingTopUp.isEmpty)
    }

    func testTopUpMessages() {
        let row = PotSummary.MemberRow(balance: balance("أحمد", paid: 100, spent: 80),
                                       credit: Money(riyals: 20), needsTopUp: true)
        let friendly = ShareMessageBuilder.topUpMessage(listName: "الدوام", row: row, suggested: Money(riyals: 100),
                                                        tone: .friendly)
        XCTAssertTrue(friendly.contains("باقي في رصيدك 20 ر.س"))
        XCTAssertTrue(friendly.contains("عبّه بـ 100 ر.س"))

        let owing = PotSummary.MemberRow(balance: balance("سعد", paid: 0, spent: 15),
                                         credit: Money(riyals: -15), needsTopUp: true)
        let formal = ShareMessageBuilder.topUpMessage(
            listName: "الدوام", row: owing, suggested: nil, tone: .formal,
            payment: PaymentDetails(iban: "SA0380000000608010167519"))
        XCTAssertTrue(formal.contains("المستحق عليك 15 ر.س"))
        XCTAssertTrue(formal.contains("الآيبان: SA03 8000 0000 6080 1016 7519"))
    }
}
