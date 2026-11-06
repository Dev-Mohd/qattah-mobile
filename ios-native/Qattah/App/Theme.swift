import SwiftUI
import UIKit
import QattahKit

extension Color {
    static let qattahAccent = Color("AccentColor")
    static let owes = Color(red: 0.86, green: 0.25, blue: 0.25)
    static let credit = Color(red: 0.06, green: 0.62, blue: 0.42)

    /// "#RRGGBB" → Color (falls back to the accent color).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = .qattahAccent
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

/// Amount with the new Saudi Riyal sign (bundled font, since older iOS
/// versions have no glyph for U+20C1).
struct MoneyText: View {
    let money: Money
    var font: Font = .body
    var weight: Font.Weight = .regular

    var body: some View {
        Text(MoneyFormatter.number(money)).font(font).fontWeight(weight).monospacedDigit()
            + Text(" ")
            + Text(MoneyFormatter.riyalSign).font(.custom("saudi_riyalregular", size: 15, relativeTo: .body))
    }
}

extension MemberBalance.Status {
    var color: Color {
        switch self {
        case .owes: .owes
        case .credit: .credit
        case .settled: .secondary
        }
    }

    var label: String {
        switch self {
        case .owes: "عليه"
        case .credit: "له"
        case .settled: "مسدّد"
        }
    }
}

enum Haptics {
    @MainActor static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Parses user-typed amounts, accepting Arabic-Indic digits and "٫" / "," as decimal separators.
enum AmountParser {
    static func money(from text: String) -> Money? {
        let arabicDigits: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "٫": ".", ",": ".",
        ]
        let normalized = String(text.map { arabicDigits[$0] ?? $0 }).trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value >= 0 else { return nil }
        return Money(riyals: value)
    }

    static func text(from money: Money) -> String {
        money.isZero ? "" : MoneyFormatter.number(money).replacingOccurrences(of: ",", with: "")
    }
}
