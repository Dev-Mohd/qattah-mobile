import Foundation

/// An amount of Saudi riyals stored as whole halalas (1 riyal = 100 halalas).
///
/// All arithmetic happens on integers so totals never drift because of
/// floating-point rounding. The database still stores `REAL` riyals for
/// compatibility with the Flutter version; convert at the boundary with
/// `Money(riyals:)` and `.riyals`.
public struct Money: Hashable, Comparable, Sendable, Codable {
    public var halalas: Int

    public init(halalas: Int) {
        self.halalas = halalas
    }

    /// Converts a riyal amount (as stored in SQLite) to halalas, rounding to the nearest halala.
    public init(riyals: Double) {
        self.halalas = Int((riyals * 100).rounded())
    }

    public static let zero = Money(halalas: 0)

    public var riyals: Double { Double(halalas) / 100 }
    public var isZero: Bool { halalas == 0 }
    public var isPositive: Bool { halalas > 0 }
    public var isNegative: Bool { halalas < 0 }
    public var magnitude: Money { Money(halalas: abs(halalas)) }

    public static func + (lhs: Money, rhs: Money) -> Money { Money(halalas: lhs.halalas + rhs.halalas) }
    public static func - (lhs: Money, rhs: Money) -> Money { Money(halalas: lhs.halalas - rhs.halalas) }
    public static prefix func - (value: Money) -> Money { Money(halalas: -value.halalas) }
    public static func += (lhs: inout Money, rhs: Money) { lhs.halalas += rhs.halalas }
    public static func -= (lhs: inout Money, rhs: Money) { lhs.halalas -= rhs.halalas }
    public static func * (lhs: Money, rhs: Int) -> Money { Money(halalas: lhs.halalas * rhs) }
    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.halalas < rhs.halalas }
}

extension Sequence where Element == Money {
    public func sum() -> Money { reduce(.zero, +) }
}

/// Formats money for display. Whole amounts show no decimals ("45"),
/// fractional amounts show two ("33.34"). Digits are Western (0-9) to match
/// the existing app and reports.
public enum MoneyFormatter {
    /// The new Saudi Riyal sign. Needs the bundled SaudiRiyal font to render.
    public static let riyalSign = "\u{20C1}"
    /// Plain-text currency label that renders everywhere (WhatsApp, SMS…).
    public static let plainCurrency = "ر.س"

    public static func number(_ money: Money) -> String {
        let value = money.halalas
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value)
        let whole = absolute / 100
        let fraction = absolute % 100
        let wholeText = groupThousands(whole)
        if fraction == 0 {
            return sign + wholeText
        }
        return sign + wholeText + "." + (fraction < 10 ? "0\(fraction)" : "\(fraction)")
    }

    /// "45 ⃁" — for in-app display with the riyal font.
    public static func display(_ money: Money) -> String {
        "\(number(money)) \(riyalSign)"
    }

    /// "45 ر.س" — for messages shared outside the app.
    public static func plain(_ money: Money) -> String {
        "\(number(money)) \(plainCurrency)"
    }

    private static func groupThousands(_ value: Int) -> String {
        let digits = String(value)
        guard digits.count > 3 else { return digits }
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 {
                result.append(",")
            }
            result.append(character)
        }
        return result
    }
}
