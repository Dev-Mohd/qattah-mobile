import Foundation

/// The "pot" (صندوق الشلة) view of a list: members pay in advance and meals
/// are deducted from their credit. It is a reading of the existing balances
/// (a negative balance is credit), not a separate ledger.
public struct PotSummary: Sendable {
    public struct MemberRow: Identifiable, Sendable {
        public var id: String { balance.id }
        public let balance: MemberBalance
        /// Credit left in the pot; negative when the member owes.
        public let credit: Money
        public let needsTopUp: Bool
    }

    /// Money the organizer is holding: everything paid in minus everything
    /// spent. Negative means the organizer has paid out of pocket.
    public let balance: Money
    /// Average spending per calendar day over the look-back window.
    public let averageDailySpending: Money
    /// How many days the pot lasts at that pace (nil if unknown or empty).
    public let daysLeft: Int?
    public let threshold: Money
    /// Lowest credit first.
    public let members: [MemberRow]

    public var membersNeedingTopUp: [MemberRow] { members.filter(\.needsTopUp) }
}

public enum PotCalculator {
    public static let lookbackDays = 14

    public static func summary(balances: ListBalances, records: [MealRecord], threshold: Money,
                               today: Day = .today(), calendar: Calendar = .current) -> PotSummary {
        let potBalance = -(balances.members.map(\.net).sum() + balances.unassigned.map(\.amount).sum())

        let start = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: today.date(calendar: calendar))
            .map { Day($0, calendar: calendar) } ?? today
        let recentSpending = records.filter { $0.day >= start && $0.day <= today }.map(\.totalAmount).sum()
        let average = Money(halalas: recentSpending.halalas / lookbackDays)

        let daysLeft: Int? = potBalance.isPositive && average.isPositive
            ? potBalance.halalas / average.halalas
            : nil

        let rows = balances.members
            .filter { $0.member.isActive || !$0.net.isZero }
            .map { balance -> PotSummary.MemberRow in
                let credit = -balance.net
                return PotSummary.MemberRow(balance: balance, credit: credit,
                                            needsTopUp: balance.member.isActive && credit < threshold)
            }
            .sorted { $0.credit < $1.credit }

        return PotSummary(balance: potBalance, averageDailySpending: average, daysLeft: daysLeft,
                          threshold: threshold, members: rows)
    }
}

/// How reminder messages sound.
public enum MessageTone: String, CaseIterable, Sendable, Codable {
    case friendly
    case formal

    public var title: String {
        switch self {
        case .friendly: "ودّية"
        case .formal: "رسمية"
        }
    }
}

extension ShareMessageBuilder {
    /// Asks a member to top up their credit in the pot.
    public static func topUpMessage(listName: String, row: PotSummary.MemberRow, suggested: Money?,
                                    tone: MessageTone, payment: PaymentDetails? = nil) -> String {
        let name = row.balance.member.name
        var lines: [String] = []

        switch tone {
        case .friendly:
            lines.append("هلا \(name) 👋")
            if row.credit.isNegative {
                lines.append("صندوق \(listName) يسلّم عليك ☕ رصيدك خلص وعليك \(MoneyFormatter.plain(row.credit.magnitude))")
            } else if row.credit.isZero {
                lines.append("صندوق \(listName) يسلّم عليك ☕ رصيدك خلص")
            } else {
                lines.append("صندوق \(listName) يسلّم عليك ☕ باقي في رصيدك \(MoneyFormatter.plain(row.credit))")
            }
            if let suggested, suggested.isPositive {
                lines.append("عبّه بـ \(MoneyFormatter.plain(suggested)) متى ما تيسّر لك 🙏")
            } else {
                lines.append("عبّه متى ما تيسّر لك 🙏")
            }
        case .formal:
            lines.append("مرحباً \(name)")
            if row.credit.isNegative {
                lines.append("رصيدك في صندوق \(listName) انتهى، والمستحق عليك \(MoneyFormatter.plain(row.credit.magnitude)).")
            } else {
                lines.append("رصيدك المتبقي في صندوق \(listName): \(MoneyFormatter.plain(row.credit)).")
            }
            if let suggested, suggested.isPositive {
                lines.append("نأمل تعبئة الرصيد بمبلغ \(MoneyFormatter.plain(suggested)).")
            } else {
                lines.append("نأمل تعبئة الرصيد.")
            }
        }

        if let payment, !payment.isEmpty {
            lines.append("")
            lines.append(contentsOf: payment.messageLines)
        }
        return lines.joined(separator: "\n")
    }
}
