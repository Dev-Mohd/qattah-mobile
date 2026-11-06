import Foundation

/// Reads a bank / wallet "money received" SMS that the user pasted or shared,
/// and extracts the amount and the sender's name.
///
/// Message formats differ between banks and change over time, so this is a
/// best-effort helper: the user always confirms (and can correct) the result.
public struct ParsedBankMessage: Equatable, Sendable {
    public var amount: Money?
    public var senderName: String?
    /// Looks like money coming in (not a purchase or outgoing transfer).
    public var isIncoming: Bool
}

public enum BankMessageParser {
    public static func parse(_ text: String) -> ParsedBankMessage {
        let normalized = normalizeDigits(text)
        return ParsedBankMessage(amount: amount(in: normalized),
                                 senderName: sender(in: normalized),
                                 isIncoming: isIncoming(normalized))
    }

    // MARK: Amount

    private static let currency = #"(?:SAR|SR|ريال|ر\.?\s?س|﷼|\x{20C1})"#
    private static let number = #"([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)"#

    static func amount(in text: String) -> Money? {
        let patterns = [
            // "مبلغ: SAR 50.00" / "Amount: 50 SAR" / "بمبلغ 50 ريال"
            #"(?:مبلغ|المبلغ|بمبلغ|Amount|Amt)\s*[:：]?\s*"# + currency + #"?\s*"# + number,
            // "SAR 50.00"
            currency + #"\s*"# + number,
            // "50.00 SAR" / "50 ريال"
            number + #"\s*"# + currency,
        ]
        for pattern in patterns {
            if let match = firstMatch(pattern, in: text),
               let value = Double(match.replacingOccurrences(of: ",", with: "")), value > 0 {
                return Money(riyals: value)
            }
        }
        return nil
    }

    // MARK: Sender

    static func sender(in text: String) -> String? {
        let patterns = [
            // "من: AHMED ALI" / "From: Ahmed" / "المرسل: أحمد" / "اسم المحول: ..."
            #"(?:من|From|المرسل|المحول|اسم المحول|Sender)\s*[:：]\s*([^\n\r]+)"#,
            // "تم استلام 50 ريال من أحمد علي"
            #"(?:استلام|إيداع|ايداع|حوالة)[^\n\r]*?\sمن\s+([^\n\r]+)"#,
        ]
        for pattern in patterns {
            guard var name = firstMatch(pattern, in: text) else { continue }
            // Cut at the next field / punctuation.
            for stop in ["إلى", " to ", " الى", "في ", " on ", "،", ",", "|", " - ", "رقم", "IBAN", "حساب"] {
                if let range = name.range(of: stop, options: .caseInsensitive) {
                    name = String(name[..<range.lowerBound])
                }
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            // Ignore account numbers or masked cards.
            if name.isEmpty || name.allSatisfy({ $0.isNumber || $0 == "*" || $0 == " " }) { continue }
            return name
        }
        return nil
    }

    static func isIncoming(_ text: String) -> Bool {
        let incoming = ["واردة", "وارده", "استلام", "إيداع", "ايداع", "incoming", "received", "credited", "deposit"]
        let outgoing = ["صادرة", "صادره", "شراء", "سحب", "outgoing", "purchase", "debited"]
        let lower = text.lowercased()
        if outgoing.contains(where: { lower.contains($0) }) { return false }
        return incoming.contains(where: { lower.contains($0) })
    }

    // MARK: Matching

    /// The member whose name best matches the sender (or nil if none does).
    /// Matches on shared name words after normalizing Arabic spelling, so
    /// "محمد عبدالله" matches "محمد", and "AHMED ALI" matches "Ahmed".
    public static func bestMatch(sender: String, members: [Member]) -> Member? {
        let senderWords = Set(words(sender))
        guard !senderWords.isEmpty else { return nil }
        let scored = members.compactMap { member -> (Member, Int)? in
            let memberWords = words(member.name)
            let common = memberWords.filter { senderWords.contains($0) }.count
            return common > 0 ? (member, common * 10 - memberWords.count) : nil
        }
        let best = scored.max { $0.1 < $1.1 }
        // Ambiguous (two members tie)? Let the user choose.
        if let best, scored.filter({ $0.1 == best.1 }).count == 1 { return best.0 }
        return nil
    }

    static func words(_ name: String) -> [String] {
        normalizeArabic(name.lowercased())
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count > 1 }
    }

    static func normalizeArabic(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ة", "ه"), ("ى", "ي"), ("ؤ", "و"), ("ئ", "ي"), ("ـ", ""),
        ]
        for (from, to) in replacements { result = result.replacingOccurrences(of: from, with: to) }
        // Remove diacritics (tashkeel).
        return result.unicodeScalars.filter { !(0x064B...0x0652).contains($0.value) }
            .map(String.init).joined()
    }

    // MARK: Helpers

    static func normalizeDigits(_ text: String) -> String {
        let map: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "٫": ".", "٬": ",",
        ]
        return String(text.map { map[$0] ?? $0 })
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captured])
    }
}
