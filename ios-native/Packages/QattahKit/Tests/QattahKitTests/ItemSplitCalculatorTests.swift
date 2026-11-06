import XCTest
@testable import QattahKit

final class ItemSplitCalculatorTests: XCTestCase {
    private func line(_ member: String?, _ name: String, _ price: Double, qty: Int = 1) -> OrderLine {
        OrderLine(recordId: "r", memberId: member, itemName: name, unitPrice: Money(riyals: price), quantity: qty)
    }

    func testEachPaysForOwnItems() {
        let result = ItemSplitCalculator.split(
            lines: [line("a", "فول", 8), line("b", "تميس", 3, qty: 2), line("b", "شاي", 2)],
            attendeeIds: ["a", "b"])
        XCTAssertEqual(result.shares.map(\.share), [Money(riyals: 8), Money(riyals: 8)])
        XCTAssertEqual(result.total, Money(riyals: 16))
    }

    func testSharedItemsSplitEquallyAndExtrasProportionally() {
        // a: 10, b: 30, shared plate 9 → 3 each to a, b, c. Delivery 10.
        let result = ItemSplitCalculator.split(
            lines: [line("a", "فول", 10), line("b", "مشكل", 30), line(nil, "صحن مشترك", 9)],
            attendeeIds: ["a", "b", "c"],
            extras: Money(riyals: 10))
        // base: a 13, b 33, c 3 (total 49); delivery 10 split 13/49, 33/49, 3/49
        let shares = result.shares.map(\.share)
        XCTAssertEqual(shares.sum(), Money(riyals: 59))
        XCTAssertEqual(shares[0].halalas, 1300 + 265) // 2.653… → 2.65
        XCTAssertEqual(shares[1].halalas, 3300 + 674) // 6.734… → 6.73 + leftover halala
        XCTAssertEqual(shares[2].halalas, 300 + 61)   // 0.612… → 0.61
    }

    func testDiscountReducesShares() {
        let result = ItemSplitCalculator.split(
            lines: [line("a", "x", 20), line("b", "y", 20)],
            attendeeIds: ["a", "b"], extras: Money(riyals: -4))
        XCTAssertEqual(result.shares.map(\.share), [Money(riyals: 18), Money(riyals: 18)])
    }

    func testIgnoresLinesOfAbsentMembers() {
        let result = ItemSplitCalculator.split(lines: [line("a", "x", 5), line("z", "y", 50)], attendeeIds: ["a"])
        XCTAssertEqual(result.total, Money(riyals: 5))
    }

    func testOnlyExtrasSplitEqually() {
        let result = ItemSplitCalculator.split(lines: [], attendeeIds: ["a", "b", "c"], extras: Money(riyals: 10))
        XCTAssertEqual(result.shares.map(\.share.halalas), [334, 333, 333])
    }

    func testProportionalAlwaysSumsExactly() {
        for amount in [1, 99, 1000, 12_345, -777] {
            let parts = ItemSplitCalculator.proportional(Money(halalas: amount), weights: [7, 13, 1, 29])
            XCTAssertEqual(parts.sum().halalas, amount)
        }
    }

    func testRestaurantOrderGroupsItems() {
        let lines = [line("a", "فول", 8), line("b", "تميس", 1, qty: 2), line("c", "فول", 8), line(nil, "شاي", 2, qty: 3)]
        XCTAssertEqual(ItemSplitCalculator.restaurantOrderText(lines), "2 فول\n2 تميس\n3 شاي")
    }
}

final class PaymentDetailsTests: XCTestCase {
    func testSaudiIBANValidation() {
        XCTAssertTrue(IBAN.isValidSaudi("SA03 8000 0000 6080 1016 7519"))
        XCTAssertTrue(IBAN.isValidSaudi("sa0380000000608010167519"))
        XCTAssertFalse(IBAN.isValidSaudi("SA0380000000608010167518"))   // wrong checksum
        XCTAssertFalse(IBAN.isValidSaudi("AE070331234567890123456"))    // not Saudi
        XCTAssertFalse(IBAN.isValidSaudi("SA03"))
        XCTAssertEqual(IBAN.grouped("SA0380000000608010167519"), "SA03 8000 0000 6080 1016 7519")
    }

    func testWhatsAppDigits() {
        XCTAssertEqual(PhoneNumber.whatsAppDigits("055 123 4567"), "966551234567")
        XCTAssertEqual(PhoneNumber.whatsAppDigits("+966 55 123 4567"), "966551234567")
        XCTAssertEqual(PhoneNumber.whatsAppDigits("00966551234567"), "966551234567")
        XCTAssertEqual(PhoneNumber.whatsAppDigits("٠٥٥١٢٣٤٥٦٧"), "966551234567")
        XCTAssertNil(PhoneNumber.whatsAppDigits("123"))
    }

    func testReminderIncludesPaymentDetails() {
        let member = Member(id: "a", listId: "l", name: "أحمد")
        let balance = MemberBalance(member: member, openingBalance: .zero, spent: Money(riyals: 30),
                                    paid: .zero, mealCount: 2)
        let text = ShareMessageBuilder.reminderMessage(
            listName: "الدوام", balance: balance,
            payment: PaymentDetails(holderName: "محمد", bankName: "الراجحي", iban: "SA0380000000608010167519"))
        XCTAssertTrue(text.contains("المتبقي عليك في قطّة الدوام: 30 ر.س"))
        XCTAssertTrue(text.contains("الآيبان: SA03 8000 0000 6080 1016 7519 (الراجحي)"))
    }
}
