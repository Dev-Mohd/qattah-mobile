import Foundation

/// Splits a meal's total among the attendees without losing a single halala.
///
/// The Flutter version rounded each share to 2 decimals, so 100 ⃁ between 3
/// people became 33.33 × 3 = 99.99 and one halala disappeared per meal.
/// Here the remainder is handed out one halala at a time to the first
/// attendees, so the shares always add up to the total exactly:
/// 100 / 3 → 33.34, 33.33, 33.33.
public enum SplitCalculator {
    /// Returns one share per attendee, in the same order as `attendeeIds`.
    /// Returns an empty array when there are no attendees.
    public static func split<ID: Hashable>(_ total: Money, among attendeeIds: [ID]) -> [(id: ID, share: Money)] {
        let count = attendeeIds.count
        guard count > 0 else { return [] }

        let sign = total.halalas < 0 ? -1 : 1
        let absolute = abs(total.halalas)
        let base = absolute / count
        let remainder = absolute % count

        return attendeeIds.enumerated().map { index, id in
            let extra = index < remainder ? 1 : 0
            return (id: id, share: Money(halalas: sign * (base + extra)))
        }
    }

    /// Convenience: the "headline" per-person amount shown in the UI
    /// (the largest share, i.e. what most people pay rounded up by at most one halala).
    public static func perPerson(_ total: Money, attendeeCount: Int) -> Money {
        guard attendeeCount > 0 else { return .zero }
        let absolute = abs(total.halalas)
        let base = absolute / attendeeCount
        let extra = absolute % attendeeCount == 0 ? 0 : 1
        return Money(halalas: (total.halalas < 0 ? -1 : 1) * (base + extra))
    }

    /// Equal split where one-time guests count as people and their share is
    /// charged to their host. Returns one entry per person: members first
    /// (in order), then guests.
    public static func splitWithGuests(_ total: Money, attendeeIds: [String],
                                       guests: [Guest]) -> [GuestAwareShare] {
        let slots = attendeeIds.map { GuestAwareShare(memberId: $0, guestName: nil, share: .zero) }
            + guests.map { GuestAwareShare(memberId: $0.hostId, guestName: $0.name, share: .zero) }
        let shares = split(total, among: Array(slots.indices))
        return zip(slots, shares).map { slot, part in
            GuestAwareShare(memberId: slot.memberId, guestName: slot.guestName, share: part.share)
        }
    }
}

/// A one-time guest, paid for by a member.
public struct Guest: Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var hostId: String

    public init(id: String = UUID().uuidString.lowercased(), name: String, hostId: String) {
        self.id = id
        self.name = name
        self.hostId = hostId
    }
}

public struct GuestAwareShare: Hashable, Sendable {
    public let memberId: String
    public let guestName: String?
    public let share: Money
}
