import Foundation

// Plain value types used by the UI and the business logic.
// They mirror the tables of the existing SQLite database (shared with the
// Flutter version) but use `Money` instead of `Double` for amounts.

public struct QattahList: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// Hex color such as "#2563EB".
    public var color: String
    public var icon: String?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString.lowercased(), name: String, color: String = "#10B981",
                icon: String? = nil, isArchived: Bool = false,
                createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Member: Identifiable, Hashable, Sendable {
    public var id: String
    public var listId: String
    public var name: String
    public var emoji: String
    public var isActive: Bool
    /// Positive = owed to the pot before the app was used; negative = credit.
    public var openingBalance: Money
    /// Pre-selected when logging a new meal.
    public var isDefaultAttendee: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString.lowercased(), listId: String, name: String,
                emoji: String = "👤", isActive: Bool = true, openingBalance: Money = .zero,
                isDefaultAttendee: Bool = true, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.listId = listId
        self.name = name
        self.emoji = emoji
        self.isActive = isActive
        self.openingBalance = openingBalance
        self.isDefaultAttendee = isDefaultAttendee
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct MealType: Identifiable, Hashable, Sendable {
    public var id: String
    public var listId: String
    public var name: String
    /// Price per person. Zero means "no default".
    public var defaultPrice: Money
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString.lowercased(), listId: String, name: String,
                defaultPrice: Money = .zero, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.listId = listId
        self.name = name
        self.defaultPrice = defaultPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A logged meal (table `records`).
public struct MealRecord: Identifiable, Hashable, Sendable {
    public var id: String
    public var listId: String
    public var mealTypeId: String?
    public var mealName: String
    /// Calendar day of the meal.
    public var day: Day
    public var totalAmount: Money
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString.lowercased(), listId: String, mealTypeId: String?,
                mealName: String, day: Day, totalAmount: Money, note: String = "",
                createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.listId = listId
        self.mealTypeId = mealTypeId
        self.mealName = mealName
        self.day = day
        self.totalAmount = totalAmount
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// One attendee's share of a meal (table `record_participants`).
public struct Participant: Identifiable, Hashable, Sendable {
    public var id: String
    public var recordId: String
    /// `nil` when the member was deleted after the meal was logged.
    public var memberId: String?
    /// Name snapshot taken when the meal was logged.
    public var memberName: String
    public var share: Money

    public init(id: String = UUID().uuidString.lowercased(), recordId: String, memberId: String?,
                memberName: String, share: Money) {
        self.id = id
        self.recordId = recordId
        self.memberId = memberId
        self.memberName = memberName
        self.share = share
    }
}

public struct Payment: Identifiable, Hashable, Sendable {
    public var id: String
    public var listId: String
    public var memberId: String?
    public var memberName: String
    public var amount: Money
    public var note: String
    /// The day the money was actually paid (may differ from `createdAt`).
    public var paidOn: Day
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString.lowercased(), listId: String, memberId: String?,
                memberName: String, amount: Money, note: String = "", paidOn: Day,
                createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.listId = listId
        self.memberId = memberId
        self.memberName = memberName
        self.amount = amount
        self.note = note
        self.paidOn = paidOn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// A calendar day stored as "yyyy-MM-dd" (the format used by the existing database).
public struct Day: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses "yyyy-MM-dd" or any ISO-8601 string starting with it.
    public init?(_ text: String) {
        let parts = text.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(calendar: Calendar = .current) -> Day { Day(.now, calendar: calendar) }

    /// "yyyy-MM-dd"
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// "yyyy-MM" — the key used to group reports by month.
    public var monthKey: String { String(format: "%04d-%02d", year, month) }

    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
