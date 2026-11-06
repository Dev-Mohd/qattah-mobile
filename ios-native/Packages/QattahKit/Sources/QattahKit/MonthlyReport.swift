import Foundation

/// A calendar month ("2026-11").
public struct Month: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(_ day: Day) {
        self.init(year: day.year, month: day.month)
    }

    public static func current(calendar: Calendar = .current) -> Month { Month(Day.today(calendar: calendar)) }

    /// "yyyy-MM" — same as `Day.monthKey`.
    public var description: String { String(format: "%04d-%02d", year, month) }

    public var previous: Month {
        month == 1 ? Month(year: year - 1, month: 12) : Month(year: year, month: month - 1)
    }

    public var next: Month {
        month == 12 ? Month(year: year + 1, month: 1) : Month(year: year, month: month + 1)
    }

    public var firstDay: Day { Day(year: year, month: month, day: 1) }

    public func contains(_ day: Day) -> Bool { day.year == year && day.month == month }

    /// "نوفمبر 2026" (Gregorian, Arabic month names, Western digits).
    public var arabicTitle: String {
        let names = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
                     "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
        return "\(names[month - 1]) \(year)"
    }

    public static func < (lhs: Month, rhs: Month) -> Bool { (lhs.year, lhs.month) < (rhs.year, rhs.month) }
}

/// One member's numbers for a month.
public struct MemberMonthStat: Identifiable, Hashable, Sendable {
    public var id: String { member.id }
    public let member: Member
    /// Balance carried in from before the month (opening balance + earlier activity).
    public let carriedIn: Money
    public let mealCount: Int
    public let spent: Money
    public let paid: Money

    /// Balance at the end of the month. Positive = owes.
    public var closing: Money { carriedIn + spent - paid }
}

public struct MonthlyReport: Sendable {
    public let month: Month
    public let members: [MemberMonthStat]
    public let mealCount: Int
    public let paymentCount: Int
    public let totalSpent: Money
    public let totalPaid: Money
    /// Spending per day of the month (only days with meals), oldest first.
    public let dailySpending: [(day: Day, amount: Money)]
    /// Spending per meal name, largest first.
    public let spendingByMeal: [(name: String, amount: Money, count: Int)]

    public var isEmpty: Bool { mealCount == 0 && paymentCount == 0 }
    /// Total still owed at the end of the month.
    public var closingOwed: Money { members.map(\.closing).filter(\.isPositive).sum() }
    public var averageMeal: Money {
        mealCount == 0 ? .zero : Money(halalas: totalSpent.halalas / mealCount)
    }
}

public enum MonthlyReportBuilder {
    /// Builds the report for `month`. Unlike the Flutter version (which only
    /// looked at the month in isolation), each member's balance carried in
    /// from earlier months is included, so the closing figure matches the
    /// balances screen.
    public static func build(
        month: Month,
        members: [Member],
        records: [MealRecord],
        participants: [Participant],
        payments: [Payment]
    ) -> MonthlyReport {
        let before = BalanceCalculator.balances(
            members: members,
            records: records.filter { $0.day < month.firstDay },
            participants: participants,
            payments: payments.filter { $0.paidOn < month.firstDay }
        )

        let monthRecords = records.filter { month.contains($0.day) }
        let monthPayments = payments.filter { month.contains($0.paidOn) }
        let withoutOpening = members.map { member -> Member in
            var copy = member
            copy.openingBalance = .zero
            return copy
        }
        let during = BalanceCalculator.balances(
            members: withoutOpening,
            records: monthRecords,
            participants: participants,
            payments: monthPayments
        )

        let carried = Dictionary(uniqueKeysWithValues: before.members.map { ($0.id, $0.net) })
        let stats = during.members.compactMap { row -> MemberMonthStat? in
            let original = members.first { $0.id == row.id } ?? row.member
            let carriedIn = carried[row.id] ?? .zero
            // Hide inactive members with nothing to show this month.
            if !original.isActive && row.mealCount == 0 && row.paid.isZero && carriedIn.isZero { return nil }
            return MemberMonthStat(member: original, carriedIn: carriedIn, mealCount: row.mealCount,
                                   spent: row.spent, paid: row.paid)
        }
        .sorted { $0.closing > $1.closing }

        var daily: [Day: Money] = [:]
        var byMeal: [String: (Money, Int)] = [:]
        for record in monthRecords {
            daily[record.day, default: .zero] += record.totalAmount
            let current = byMeal[record.mealName] ?? (.zero, 0)
            byMeal[record.mealName] = (current.0 + record.totalAmount, current.1 + 1)
        }

        return MonthlyReport(
            month: month,
            members: stats,
            mealCount: monthRecords.count,
            paymentCount: monthPayments.count,
            totalSpent: monthRecords.map(\.totalAmount).sum(),
            totalPaid: monthPayments.map(\.amount).sum(),
            dailySpending: daily.sorted { $0.key < $1.key }.map { (day: $0.key, amount: $0.value) },
            spendingByMeal: byMeal
                .map { (name: $0.key, amount: $0.value.0, count: $0.value.1) }
                .sorted { $0.amount > $1.amount }
        )
    }

    /// Months that have any activity, newest first (always includes the current month).
    public static func activeMonths(records: [MealRecord], payments: [Payment],
                                    current: Month = .current()) -> [Month] {
        var months = Set(records.map { Month($0.day) })
        months.formUnion(payments.map { Month($0.paidOn) })
        months.insert(current)
        return months.sorted(by: >)
    }

    /// Plain-text version of the report for sharing.
    public static func shareText(listName: String, report: MonthlyReport) -> String {
        var lines = ["📊 تقرير قطّة \(listName) — \(report.month.arabicTitle)", ""]
        lines.append("عدد الوجبات: \(report.mealCount)")
        lines.append("مجموع المصروف: \(MoneyFormatter.plain(report.totalSpent))")
        lines.append("مجموع السداد: \(MoneyFormatter.plain(report.totalPaid))")
        lines.append("")
        for stat in report.members {
            let state: String
            if stat.closing.isPositive {
                state = "عليه \(MoneyFormatter.plain(stat.closing))"
            } else if stat.closing.isNegative {
                state = "له \(MoneyFormatter.plain(stat.closing.magnitude))"
            } else {
                state = "مسدّد ✅"
            }
            lines.append("• \(stat.member.name): \(stat.mealCount) وجبة — \(state)")
        }
        lines.append("")
        lines.append("— أُرسلت من تطبيق قطّه")
        return lines.joined(separator: "\n")
    }
}
