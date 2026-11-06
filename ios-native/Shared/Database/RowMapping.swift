import Foundation
import GRDB
import QattahKit

/// Date strings in the database look like "2026-11-05T13:45:12.345678"
/// (Dart's `toIso8601String()`, local time, no zone). Keep that format so
/// prefix-based grouping ("2026-11") keeps working for both apps.
enum DBDate {
    private static let writer: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return f
    }()

    private static let readers: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd",
    ].map { format in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    private static let iso = ISO8601DateFormatter()

    static func string(_ date: Date) -> String { writer.string(from: date) }

    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if text.hasSuffix("Z") || text.contains("+") { return iso.date(from: text) }
        for reader in readers {
            if let date = reader.date(from: text) { return date }
        }
        return nil
    }
}

private extension Row {
    func string(_ column: String, default fallback: String = "") -> String {
        (self[column] as String?) ?? fallback
    }

    func optionalString(_ column: String) -> String? {
        guard let value = self[column] as String?, !value.isEmpty else { return nil }
        return value
    }

    func money(_ column: String) -> Money {
        Money(riyals: (self[column] as Double?) ?? 0)
    }

    func bool(_ column: String, default fallback: Bool) -> Bool {
        guard let value = self[column] as Int? else { return fallback }
        return value != 0
    }

    func date(_ column: String, fallback: String? = nil) -> Date {
        DBDate.date(self[column] as String?)
            ?? DBDate.date(fallback.flatMap { self[$0] as String? })
            ?? Date(timeIntervalSince1970: 0)
    }
}

extension QattahList {
    init(row: Row) {
        self.init(id: row.string("id"),
                  name: row.string("name", default: "بدون اسم"),
                  color: row.string("color", default: "#2563EB"),
                  icon: row.optionalString("icon"),
                  isArchived: row.bool("is_archived", default: false),
                  createdAt: row.date("created_at"),
                  updatedAt: row.date("updated_at", fallback: "created_at"))
    }
}

extension Member {
    init(row: Row) {
        self.init(id: row.string("id"),
                  listId: row.string("list_id"),
                  name: row.string("name", default: "بدون اسم"),
                  emoji: row.string("emoji", default: "👤"),
                  isActive: row.bool("is_active", default: true),
                  openingBalance: row.money("opening_balance"),
                  isDefaultAttendee: row.bool("is_default_attendee", default: true),
                  phone: row.optionalString("phone"),
                  createdAt: row.date("created_at"),
                  updatedAt: row.date("updated_at", fallback: "created_at"))
    }
}

extension MealType {
    init(row: Row) {
        self.init(id: row.string("id"),
                  listId: row.string("list_id"),
                  name: row.string("name", default: "بدون اسم"),
                  defaultPrice: row.money("default_price"),
                  createdAt: row.date("created_at"),
                  updatedAt: row.date("updated_at", fallback: "created_at"))
    }
}

extension MealRecord {
    init(row: Row) {
        let createdAt = row.date("created_at")
        // Old rows may only have `total_price`.
        let total = (row["total_amount"] as Double?).flatMap { $0 == 0 ? nil : $0 }
            ?? (row["total_price"] as Double?) ?? 0
        self.init(id: row.string("id"),
                  listId: row.string("list_id"),
                  mealTypeId: row.optionalString("meal_type_id"),
                  mealName: row.string("meal_name", default: "وجبة"),
                  day: Day(row.string("date")) ?? Day(createdAt),
                  totalAmount: Money(riyals: total),
                  note: row.string("note"),
                  splitMode: MealRecord.SplitMode(rawValue: row.string("split_mode")) ?? .equal,
                  extras: row.money("extras"),
                  createdAt: createdAt,
                  updatedAt: row.date("updated_at", fallback: "created_at"))
    }
}

extension Participant {
    init(row: Row) {
        self.init(id: row.string("id"),
                  recordId: row.string("record_id"),
                  memberId: row.optionalString("member_id"),
                  memberName: row.string("member_name", default: "عضو محذوف"),
                  share: row.money("share"))
    }
}

extension Payment {
    init(row: Row) {
        let createdAt = row.date("created_at")
        self.init(id: row.string("id"),
                  listId: row.string("list_id"),
                  memberId: row.optionalString("member_id"),
                  memberName: row.string("member_name", default: "عضو محذوف"),
                  amount: row.money("amount"),
                  note: row.string("note"),
                  paidOn: Day(row.string("paid_on")) ?? Day(createdAt),
                  createdAt: createdAt,
                  updatedAt: row.date("updated_at", fallback: "created_at"))
    }
}

extension MenuItem {
    init(row: Row) {
        self.init(id: row.string("id"),
                  listId: row.string("list_id"),
                  name: row.string("name"),
                  price: row.money("price"),
                  createdAt: row.date("created_at"))
    }
}

extension OrderLine {
    init(row: Row) {
        self.init(id: row.string("id"),
                  recordId: row.string("record_id"),
                  memberId: row.optionalString("member_id"),
                  itemName: row.string("item_name"),
                  unitPrice: row.money("unit_price"),
                  quantity: (row["quantity"] as Int?) ?? 1)
    }
}
