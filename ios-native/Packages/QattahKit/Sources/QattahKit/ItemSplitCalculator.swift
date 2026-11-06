import Foundation

/// Splits an itemized meal: everyone pays for what they ordered, shared items
/// are divided equally, and extras (delivery, tax, tip — or a discount when
/// negative) are divided in proportion to what each person ordered.
///
/// Every result is exact to the halala and the shares always add up to
/// `items + extras`.
public enum ItemSplitCalculator {
    public struct Result: Equatable, Sendable {
        /// One share per attendee, in attendee order.
        public let shares: [(id: String, share: Money)]
        public let itemsTotal: Money
        public let extras: Money

        public var total: Money { itemsTotal + extras }

        public static func == (lhs: Result, rhs: Result) -> Bool {
            lhs.itemsTotal == rhs.itemsTotal && lhs.extras == rhs.extras
                && lhs.shares.map(\.id) == rhs.shares.map(\.id)
                && lhs.shares.map(\.share) == rhs.shares.map(\.share)
        }
    }

    /// - Parameters:
    ///   - lines: ordered items. Lines whose `memberId` is nil are shared.
    ///     Lines of members who are not attendees are ignored.
    ///   - attendeeIds: who was there (determines shared-item and extras split).
    ///   - extras: delivery/tax/tip (positive) or discount (negative).
    public static func split(lines: [OrderLine], attendeeIds: [String], extras: Money = .zero) -> Result {
        guard !attendeeIds.isEmpty else {
            return Result(shares: [], itemsTotal: .zero, extras: extras)
        }
        let attendees = Set(attendeeIds)

        var personal: [String: Money] = [:]
        var shared = Money.zero
        for line in lines {
            if let memberId = line.memberId {
                guard attendees.contains(memberId) else { continue }
                personal[memberId, default: .zero] += line.lineTotal
            } else {
                shared += line.lineTotal
            }
        }

        // 1. What each person consumed (own items + equal part of shared items).
        let sharedParts = Dictionary(uniqueKeysWithValues:
            SplitCalculator.split(shared, among: attendeeIds).map { ($0.id, $0.share) })
        let base = attendeeIds.map { id in (personal[id] ?? .zero) + (sharedParts[id] ?? .zero) }
        let itemsTotal = base.sum()

        // 2. Extras in proportion to consumption (equally if nothing was ordered).
        let extraParts: [Money]
        if itemsTotal.halalas > 0 {
            extraParts = proportional(extras, weights: base.map(\.halalas))
        } else {
            extraParts = SplitCalculator.split(extras, among: attendeeIds).map(\.share)
        }

        let shares = zip(attendeeIds, zip(base, extraParts)).map { id, parts in
            (id: id, share: parts.0 + parts.1)
        }
        return Result(shares: shares, itemsTotal: itemsTotal, extras: extras)
    }

    /// Distributes `amount` proportionally to `weights` with the largest
    /// remainder method, so the parts add up exactly.
    static func proportional(_ amount: Money, weights: [Int]) -> [Money] {
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return weights.map { _ in .zero } }

        let sign = amount.halalas < 0 ? -1 : 1
        let absolute = abs(amount.halalas)
        var parts = weights.map { absolute * $0 / totalWeight }
        let remainders = weights.map { absolute * $0 % totalWeight }
        var leftover = absolute - parts.reduce(0, +)

        // Give the leftover halalas to the largest remainders (stable order on ties).
        let order = remainders.indices.sorted { remainders[$0] != remainders[$1] ? remainders[$0] > remainders[$1] : $0 < $1 }
        for index in order where leftover > 0 {
            parts[index] += 1
            leftover -= 1
        }
        return parts.map { Money(halalas: sign * $0) }
    }

    /// "3 فول، 2 تميس، 4 شاي" — the order to send to the restaurant.
    public static func restaurantOrder(_ lines: [OrderLine]) -> [(name: String, quantity: Int)] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (index, line) in lines.enumerated() where line.quantity > 0 {
            counts[line.itemName, default: 0] += line.quantity
            if firstSeen[line.itemName] == nil { firstSeen[line.itemName] = index }
        }
        return counts
            .map { (name: $0.key, quantity: $0.value) }
            .sorted { firstSeen[$0.name, default: 0] < firstSeen[$1.name, default: 0] }
    }

    public static func restaurantOrderText(_ lines: [OrderLine]) -> String {
        restaurantOrder(lines).map { "\($0.quantity) \($0.name)" }.joined(separator: "\n")
    }
}
