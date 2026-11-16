import XCTest
@testable import QattahKit

final class SettlementPlannerTests: XCTestCase {
    private func balances(_ nets: [(String, Double)]) -> ListBalances {
        ListBalances(members: nets.map { id, net in
            MemberBalance(member: Member(id: id, listId: "l", name: id), openingBalance: .zero,
                          spent: net > 0 ? Money(riyals: net) : .zero,
                          paid: net < 0 ? Money(riyals: -net) : .zero, mealCount: 1)
        }, unassigned: [])
    }

    func testPeerSettlementUsesFewTransfers() {
        // Everything balanced among members (bills recorded with "who paid").
        let plan = SettlementPlanner.plan(balances: balances([("a", 30), ("b", 20), ("c", -50)]), organizerId: nil)
        XCTAssertEqual(plan.count, 2)
        XCTAssertTrue(plan.allSatisfy { $0.toId == "c" })
        XCTAssertEqual(plan.map(\.amount).sum(), Money(riyals: 50))
    }

    func testUnrecordedFrontingGoesToOrganizer() {
        // Nobody recorded paying: all 60 is owed to the organizer.
        let plan = SettlementPlanner.plan(balances: balances([("a", 40), ("b", 20)]), organizerId: nil)
        XCTAssertEqual(plan.count, 2)
        XCTAssertTrue(plan.allSatisfy { $0.toId == nil && $0.toName == SettlementPlanner.organizerFallbackName })
    }

    func testOrganizerAsMemberNetsTheirOwnShare() {
        // a is the organizer and ate 20; b ate 30. Pot = 50 → b pays a 30, a pays nobody.
        let plan = SettlementPlanner.plan(balances: balances([("a", 20), ("b", 30)]), organizerId: "a")
        XCTAssertEqual(plan, [Transfer(fromId: "b", fromName: "b", toId: "a", toName: "a", amount: Money(riyals: 30))])
    }

    func testRecordingTransfersSettlesEverything() {
        let start = [("a", 30.0), ("b", 20.0), ("c", -50.0)]
        let plan = SettlementPlanner.plan(balances: balances(start), organizerId: nil)
        var nets = Dictionary(uniqueKeysWithValues: start.map { ($0.0, Money(riyals: $0.1)) })
        for transfer in plan {
            for payment in SettlementPlanner.payments(for: transfer, listId: "l", organizerId: nil, on: .today()) {
                nets[payment.memberId!, default: .zero] -= payment.amount
            }
        }
        XCTAssertTrue(nets.values.allSatisfy(\.isZero))
    }
}

final class BankMessageParserTests: XCTestCase {
    func testArabicIncomingTransfer() {
        let sms = """
        حوالة واردة محلية
        مبلغ: SAR 45.50
        من: احمد علي
        إلى: 1234
        """
        let parsed = BankMessageParser.parse(sms)
        XCTAssertEqual(parsed.amount, Money(riyals: 45.5))
        XCTAssertEqual(parsed.senderName, "احمد علي")
        XCTAssertTrue(parsed.isIncoming)
    }

    func testEnglishIncomingTransfer() {
        let parsed = BankMessageParser.parse("Incoming transfer\nAmount: 1,250.00 SAR\nFrom: SAAD AL-QAHTANI\nOn: 05/11")
        XCTAssertEqual(parsed.amount, Money(riyals: 1250))
        XCTAssertEqual(parsed.senderName, "SAAD AL-QAHTANI")
        XCTAssertTrue(parsed.isIncoming)
    }

    func testWalletStyleSentence() {
        let parsed = BankMessageParser.parse("تم استلام ٣٠ ريال من فهد محمد في محفظتك")
        XCTAssertEqual(parsed.amount, Money(riyals: 30))
        XCTAssertEqual(parsed.senderName, "فهد محمد")
    }

    func testPurchaseIsNotIncoming() {
        XCTAssertFalse(BankMessageParser.parse("شراء عبر نقاط البيع بمبلغ 20 SAR").isIncoming)
    }

    func testMemberMatching() {
        let members = [Member(id: "1", listId: "l", name: "أحمد"), Member(id: "2", listId: "l", name: "سعد"),
                       Member(id: "3", listId: "l", name: "Saad Q")]
        XCTAssertEqual(BankMessageParser.bestMatch(sender: "احمد علي", members: members)?.id, "1")
        XCTAssertEqual(BankMessageParser.bestMatch(sender: "SAAD AL QAHTANI", members: members)?.id, "3")
        XCTAssertNil(BankMessageParser.bestMatch(sender: "خالد", members: members))
    }
}
