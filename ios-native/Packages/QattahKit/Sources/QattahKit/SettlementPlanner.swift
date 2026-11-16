import Foundation

/// One money transfer in a settlement plan.
public struct Transfer: Hashable, Identifiable, Sendable {
    public var id: String { "\(fromId)→\(toId ?? "organizer")" }
    public let fromId: String
    public let fromName: String
    /// `nil` = the organizer who is not a member of the list (whoever paid
    /// the meals that have no recorded payer).
    public let toId: String?
    public let toName: String
    public let amount: Money

    public init(fromId: String, fromName: String, toId: String?, toName: String, amount: Money) {
        self.fromId = fromId
        self.fromName = fromName
        self.toId = toId
        self.toName = toName
        self.amount = amount
    }
}

/// Works out who should pay whom so that every balance goes to zero, with
/// as few transfers as possible (greedy: largest debtor pays largest creditor).
///
/// In Qattah a positive balance means "owes the pot". The sum of all
/// balances is what the organizer fronted without it being recorded as a
/// payment (meals with no "who paid"). That amount is owed to the organizer:
/// - if the organizer is a member, it is netted against their own balance;
/// - otherwise it appears as a separate creditor named "المنظّم".
public enum SettlementPlanner {
    public static let organizerFallbackName = "المنظّم"

    public static func plan(balances: ListBalances, organizerId: String?) -> [Transfer] {
        var positions: [(id: String?, name: String, net: Int)] = balances.members.map {
            (id: $0.member.id, name: $0.member.name, net: $0.net.halalas)
        }
        let pot = positions.reduce(0) { $0 + $1.net }

        if let organizerId, let index = positions.firstIndex(where: { $0.id == organizerId }) {
            positions[index].net -= pot
        } else if pot != 0 {
            positions.append((id: nil, name: organizerFallbackName, net: -pot))
        }

        var debtors = positions.filter { $0.net > 0 }.sorted { $0.net > $1.net }
        var creditors = positions.filter { $0.net < 0 }.map { (id: $0.id, name: $0.name, net: -$0.net) }
            .sorted { $0.net > $1.net }

        var transfers: [Transfer] = []
        var d = 0
        var c = 0
        while d < debtors.count && c < creditors.count {
            let amount = min(debtors[d].net, creditors[c].net)
            if amount > 0, let fromId = debtors[d].id {
                transfers.append(Transfer(fromId: fromId, fromName: debtors[d].name,
                                          toId: creditors[c].id, toName: creditors[c].name,
                                          amount: Money(halalas: amount)))
            }
            debtors[d].net -= amount
            creditors[c].net -= amount
            if debtors[d].net == 0 { d += 1 }
            if creditors[c].net == 0 { c += 1 }
        }
        return transfers
    }

    /// The payments to record once a transfer has happened.
    /// - The payer's balance goes down by the amount.
    /// - A member who *received* money has their credit reduced (a negative
    ///   payment), unless they are the organizer: money paid to the organizer
    ///   repays what they fronted for the pot.
    public static func payments(for transfer: Transfer, listId: String, organizerId: String?,
                                on day: Day) -> [Payment] {
        var result = [Payment(listId: listId, memberId: transfer.fromId, memberName: transfer.fromName,
                              amount: transfer.amount, note: "تحويل إلى \(transfer.toName)", paidOn: day)]
        if let toId = transfer.toId, toId != organizerId {
            result.append(Payment(listId: listId, memberId: toId, memberName: transfer.toName,
                                  amount: -transfer.amount, note: "استلم من \(transfer.fromName)", paidOn: day))
        }
        return result
    }

    public static func message(for transfer: Transfer, listName: String, payment: PaymentDetails?) -> String {
        var lines = [
            "مرحباً \(transfer.fromName) 👋",
            "لتصفية حساب قطّة \(listName): حوّل \(MoneyFormatter.plain(transfer.amount)) إلى \(transfer.toName)",
        ]
        if transfer.toId == nil, let payment, !payment.isEmpty {
            lines.append("")
            lines.append(contentsOf: payment.messageLines)
        }
        lines.append("شكراً لك 🙏")
        return lines.joined(separator: "\n")
    }
}
