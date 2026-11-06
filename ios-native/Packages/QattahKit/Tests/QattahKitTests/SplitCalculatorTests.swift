import XCTest
@testable import QattahKit

final class SplitCalculatorTests: XCTestCase {
    func testEvenSplit() {
        let shares = SplitCalculator.split(Money(riyals: 90), among: ["a", "b", "c"])
        XCTAssertEqual(shares.map(\.share), [Money(riyals: 30), Money(riyals: 30), Money(riyals: 30)])
    }

    func testRemainderIsNeverLost() {
        // The Flutter version produced 33.33 × 3 = 99.99 here.
        let shares = SplitCalculator.split(Money(riyals: 100), among: ["a", "b", "c"])
        XCTAssertEqual(shares.map(\.share.halalas), [3334, 3333, 3333])
        XCTAssertEqual(shares.map(\.share).sum(), Money(riyals: 100))
    }

    func testSharesAlwaysSumToTotal() {
        for total in [1, 7, 99, 100, 1001, 12_345, 99_999] {
            for count in 1...13 {
                let ids = Array(0..<count)
                let shares = SplitCalculator.split(Money(halalas: total), among: ids)
                XCTAssertEqual(shares.map(\.share).sum().halalas, total, "total \(total) / \(count)")
                let values = shares.map(\.share.halalas)
                XCTAssertLessThanOrEqual(values.max()! - values.min()!, 1)
            }
        }
    }

    func testKeepsAttendeeOrder() {
        let shares = SplitCalculator.split(Money(halalas: 5), among: ["x", "y"])
        XCTAssertEqual(shares.map(\.id), ["x", "y"])
        XCTAssertEqual(shares.map(\.share.halalas), [3, 2])
    }

    func testNoAttendees() {
        XCTAssertTrue(SplitCalculator.split(Money(riyals: 50), among: [String]()).isEmpty)
        XCTAssertEqual(SplitCalculator.perPerson(Money(riyals: 50), attendeeCount: 0), .zero)
    }

    func testPerPersonRoundsUpToTheLargestShare() {
        XCTAssertEqual(SplitCalculator.perPerson(Money(riyals: 100), attendeeCount: 3).halalas, 3334)
        XCTAssertEqual(SplitCalculator.perPerson(Money(riyals: 90), attendeeCount: 3).halalas, 3000)
    }
}

final class MoneyTests: XCTestCase {
    func testRoundTripFromDatabaseReal() {
        XCTAssertEqual(Money(riyals: 33.33).halalas, 3333)
        XCTAssertEqual(Money(riyals: 0.1 + 0.2).halalas, 30)
        XCTAssertEqual(Money(riyals: -12.5).halalas, -1250)
    }

    func testFormatting() {
        XCTAssertEqual(MoneyFormatter.number(Money(riyals: 45)), "45")
        XCTAssertEqual(MoneyFormatter.number(Money(riyals: 12.5)), "12.50")
        XCTAssertEqual(MoneyFormatter.number(Money(halalas: 5)), "0.05")
        XCTAssertEqual(MoneyFormatter.number(Money(riyals: 1234.5)), "1,234.50")
        XCTAssertEqual(MoneyFormatter.number(Money(riyals: -7)), "-7")
        XCTAssertEqual(MoneyFormatter.plain(Money(riyals: 20)), "20 ر.س")
    }

    func testDayParsing() {
        XCTAssertEqual(Day("2026-11-05")?.description, "2026-11-05")
        XCTAssertEqual(Day("2026-11-05T13:45:00.000")?.monthKey, "2026-11")
        XCTAssertNil(Day("bad"))
        XCTAssertNil(Day("2026-13-01"))
        XCTAssertLessThan(Day("2026-01-31")!, Day("2026-02-01")!)
    }
}

final class GuestSplitTests: XCTestCase {
    func testGuestShareIsChargedToHost() {
        let shares = SplitCalculator.splitWithGuests(Money(riyals: 40), attendeeIds: ["a", "b", "c"],
                                                     guests: [Guest(name: "خالد", hostId: "a")])
        XCTAssertEqual(shares.count, 4)
        XCTAssertEqual(shares.map(\.share).sum(), Money(riyals: 40))
        XCTAssertEqual(shares.last?.memberId, "a")
        XCTAssertEqual(shares.last?.guestName, "خالد")

        let balances = BalanceCalculator.balances(
            members: ["a", "b", "c"].map { Member(id: $0, listId: "l", name: $0) },
            records: [MealRecord(id: "r", listId: "l", mealTypeId: nil, mealName: "غداء",
                                 day: Day("2026-11-01")!, totalAmount: Money(riyals: 40))],
            participants: shares.map { Participant(recordId: "r", memberId: $0.memberId, memberName: $0.memberId,
                                                   share: $0.share, guestName: $0.guestName) },
            payments: [])
        let host = balances.members.first { $0.id == "a" }!
        XCTAssertEqual(host.net, Money(riyals: 20))   // own 10 + guest 10
        XCTAssertEqual(host.mealCount, 1)             // the guest is not a second meal
    }
}
