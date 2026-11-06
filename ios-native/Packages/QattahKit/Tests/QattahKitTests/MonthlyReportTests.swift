import XCTest
@testable import QattahKit

final class MonthlyReportTests: XCTestCase {
    private let a = Member(id: "a", listId: "l", name: "أحمد", openingBalance: Money(riyals: 5))
    private let b = Member(id: "b", listId: "l", name: "سعد")

    private func meal(_ id: String, _ day: String, _ total: Double, name: String = "فطور") -> MealRecord {
        MealRecord(id: id, listId: "l", mealTypeId: nil, mealName: name, day: Day(day)!,
                   totalAmount: Money(riyals: total))
    }

    private func share(_ record: String, _ member: Member, _ amount: Double) -> Participant {
        Participant(recordId: record, memberId: member.id, memberName: member.name, share: Money(riyals: amount))
    }

    func testCarriesBalanceFromPreviousMonths() {
        let records = [meal("oct", "2026-10-20", 20), meal("nov1", "2026-11-02", 30), meal("nov2", "2026-11-03", 10, name: "غداء")]
        let participants = [
            share("oct", a, 10), share("oct", b, 10),
            share("nov1", a, 15), share("nov1", b, 15),
            share("nov2", a, 10),
        ]
        let payments = [
            Payment(listId: "l", memberId: "b", memberName: "سعد", amount: Money(riyals: 10), paidOn: Day("2026-10-25")!),
            Payment(listId: "l", memberId: "a", memberName: "أحمد", amount: Money(riyals: 20), paidOn: Day("2026-11-04")!),
        ]

        let report = MonthlyReportBuilder.build(month: Month(year: 2026, month: 11), members: [a, b],
                                                records: records, participants: participants, payments: payments)

        let statA = report.members.first { $0.id == "a" }!
        let statB = report.members.first { $0.id == "b" }!
        XCTAssertEqual(statA.carriedIn, Money(riyals: 15))   // 5 opening + 10 in October
        XCTAssertEqual(statA.spent, Money(riyals: 25))
        XCTAssertEqual(statA.paid, Money(riyals: 20))
        XCTAssertEqual(statA.closing, Money(riyals: 20))
        XCTAssertEqual(statA.mealCount, 2)
        XCTAssertEqual(statB.carriedIn, .zero)               // 10 spent − 10 paid in October
        XCTAssertEqual(statB.closing, Money(riyals: 15))

        XCTAssertEqual(report.mealCount, 2)
        XCTAssertEqual(report.paymentCount, 1)
        XCTAssertEqual(report.totalSpent, Money(riyals: 40))
        XCTAssertEqual(report.totalPaid, Money(riyals: 20))
        XCTAssertEqual(report.dailySpending.map(\.day.description), ["2026-11-02", "2026-11-03"])
        XCTAssertEqual(report.spendingByMeal.first?.name, "فطور")
        XCTAssertEqual(report.closingOwed, Money(riyals: 35))

        // The closing figure must equal the all-time balance.
        let all = BalanceCalculator.balances(members: [a, b], records: records,
                                             participants: participants, payments: payments)
        XCTAssertEqual(all.members.first { $0.id == "a" }?.net, statA.closing)
    }

    func testMonthNavigationAndTitle() {
        let jan = Month(year: 2026, month: 1)
        XCTAssertEqual(jan.previous.description, "2025-12")
        XCTAssertEqual(Month(year: 2026, month: 12).next.description, "2027-01")
        XCTAssertEqual(Month(year: 2026, month: 11).arabicTitle, "نوفمبر 2026")
    }

    func testActiveMonthsAlwaysIncludeCurrent() {
        let months = MonthlyReportBuilder.activeMonths(records: [meal("x", "2026-08-01", 5)], payments: [],
                                                       current: Month(year: 2026, month: 11))
        XCTAssertEqual(months.map(\.description), ["2026-11", "2026-08"])
    }
}
