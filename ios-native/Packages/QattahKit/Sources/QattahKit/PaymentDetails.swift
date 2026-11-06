import Foundation

/// Where members should send money (the organizer's own details).
public struct PaymentDetails: Equatable, Sendable, Codable {
    public var holderName: String
    public var bankName: String
    /// Saudi IBAN, stored without spaces ("SA0380000000608010167519").
    public var iban: String
    /// Mobile number registered with STC Pay / urpay etc.
    public var walletPhone: String

    public init(holderName: String = "", bankName: String = "", iban: String = "", walletPhone: String = "") {
        self.holderName = holderName
        self.bankName = bankName
        self.iban = iban
        self.walletPhone = walletPhone
    }

    public var isEmpty: Bool { iban.isEmpty && walletPhone.isEmpty }

    /// Lines appended to reminders and balance messages.
    public var messageLines: [String] {
        var lines: [String] = []
        guard !isEmpty else { return lines }
        lines.append("💳 للتحويل:")
        if !holderName.isEmpty { lines.append("الاسم: \(holderName)") }
        if !iban.isEmpty {
            lines.append("الآيبان: \(IBAN.grouped(iban))" + (bankName.isEmpty ? "" : " (\(bankName))"))
        }
        if !walletPhone.isEmpty { lines.append("STC Pay / محفظة: \(walletPhone)") }
        return lines
    }
}

public enum IBAN {
    /// Removes spaces/dashes, converts Arabic-Indic digits and uppercases.
    public static func normalize(_ text: String) -> String {
        let arabicDigits: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
        ]
        return String(text.compactMap { character -> Character? in
            if character == " " || character == "-" { return nil }
            return arabicDigits[character] ?? character
        }).uppercased()
    }

    /// A valid Saudi IBAN: "SA" + 22 digits, with a correct ISO 13616 checksum.
    public static func isValidSaudi(_ text: String) -> Bool {
        let iban = normalize(text)
        guard iban.count == 24, iban.hasPrefix("SA"),
              iban.dropFirst(2).allSatisfy(\.isNumber) else { return false }
        return checksumIsValid(iban)
    }

    /// ISO 13616 mod-97 check.
    static func checksumIsValid(_ iban: String) -> Bool {
        let rearranged = iban.dropFirst(4) + iban.prefix(4)
        var remainder = 0
        for character in rearranged {
            let digits: String
            if let digit = character.wholeNumberValue, character.isASCII {
                digits = String(digit)
            } else if let ascii = character.asciiValue, character.isLetter {
                digits = String(Int(ascii) - 55) // A=10 … Z=35
            } else {
                return false
            }
            for digit in digits {
                remainder = (remainder * 10 + Int(String(digit))!) % 97
            }
        }
        return remainder == 1
    }

    /// "SA03 8000 0000 6080 1016 7519"
    public static func grouped(_ text: String) -> String {
        let iban = normalize(text)
        return stride(from: 0, to: iban.count, by: 4).map { start -> String in
            let from = iban.index(iban.startIndex, offsetBy: start)
            let to = iban.index(from, offsetBy: min(4, iban.count - start))
            return String(iban[from..<to])
        }.joined(separator: " ")
    }
}

public enum PhoneNumber {
    /// Converts a Saudi mobile number to international digits for WhatsApp:
    /// "055 123 4567" / "+966551234567" / "00966…" → "966551234567".
    /// Returns nil if it does not look like a phone number.
    public static func whatsAppDigits(_ text: String) -> String? {
        var digits = IBAN.normalize(text).filter(\.isNumber)
        if digits.hasPrefix("00") { digits.removeFirst(2) }
        if digits.hasPrefix("05") && digits.count == 10 { digits = "966" + digits.dropFirst() }
        if digits.hasPrefix("5") && digits.count == 9 { digits = "966" + digits }
        return (8...15).contains(digits.count) ? digits : nil
    }
}
