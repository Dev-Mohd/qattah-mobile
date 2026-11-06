import Foundation

/// Builds a ready-to-send text (WhatsApp, iMessage…) summarising who owes what.
///
/// Example:
/// ```
/// 🍽️ قطّة فطور الدوام
/// الأرصدة حتى 2026-11-05
///
/// 🔴 عليهم
/// • أحمد: 45 ر.س
/// • سعد: 12.50 ر.س
///
/// 🟢 لهم
/// • خالد: 20 ر.س
///
/// ✅ مسدّدين: فهد، ماجد
///
/// المجموع المطلوب: 57.50 ر.س
/// — أُرسلت من تطبيق قطّه
/// ```
public enum ShareMessageBuilder {
    public struct Options: Sendable {
        public var includeSettled: Bool
        public var includeFooter: Bool
        /// Bank / wallet details appended so people can pay right away.
        public var payment: PaymentDetails?

        public init(includeSettled: Bool = true, includeFooter: Bool = true, payment: PaymentDetails? = nil) {
            self.includeSettled = includeSettled
            self.includeFooter = includeFooter
            self.payment = payment
        }
    }

    public static func balancesMessage(listName: String, balances: ListBalances, asOf day: Day,
                                       options: Options = Options()) -> String {
        let owes = balances.members.filter { $0.status == .owes }.sorted { $0.net > $1.net }
        let credit = balances.members.filter { $0.status == .credit }.sorted { $0.net < $1.net }
        let settled = balances.members.filter { $0.status == .settled && ($0.spent.isPositive || $0.paid.isPositive) }

        var lines: [String] = []
        lines.append("🍽️ قطّة \(listName)")
        lines.append("الأرصدة حتى \(day)")

        if owes.isEmpty && credit.isEmpty {
            lines.append("")
            lines.append("✅ الكل مسدّد ولا يوجد مبالغ مستحقة")
        }

        if !owes.isEmpty {
            lines.append("")
            lines.append("🔴 عليهم")
            for row in owes {
                lines.append("• \(row.member.name): \(MoneyFormatter.plain(row.net))")
            }
        }

        if !credit.isEmpty {
            lines.append("")
            lines.append("🟢 لهم")
            for row in credit {
                lines.append("• \(row.member.name): \(MoneyFormatter.plain(row.net.magnitude))")
            }
        }

        if options.includeSettled && !settled.isEmpty {
            lines.append("")
            lines.append("✅ مسدّدين: " + settled.map(\.member.name).joined(separator: "، "))
        }

        if !owes.isEmpty {
            lines.append("")
            lines.append("المجموع المطلوب: \(MoneyFormatter.plain(balances.totalOwed))")
            if let payment = options.payment, !payment.isEmpty {
                lines.append("")
                lines.append(contentsOf: payment.messageLines)
            }
        }

        if options.includeFooter {
            lines.append("— أُرسلت من تطبيق قطّه")
        }

        return lines.joined(separator: "\n")
    }

    /// A short reminder for a single member.
    public static func reminderMessage(listName: String, balance: MemberBalance,
                                       payment: PaymentDetails? = nil) -> String {
        guard balance.status == .owes else {
            return "مرحباً \(balance.member.name) 👋\nحسابك في قطّة \(listName) مسدّد ✅"
        }
        var lines = [
            "مرحباً \(balance.member.name) 👋",
            "المتبقي عليك في قطّة \(listName): \(MoneyFormatter.plain(balance.net))",
        ]
        if let payment, !payment.isEmpty {
            lines.append("")
            lines.append(contentsOf: payment.messageLines)
        }
        lines.append("شكراً لك 🙏")
        return lines.joined(separator: "\n")
    }
}
