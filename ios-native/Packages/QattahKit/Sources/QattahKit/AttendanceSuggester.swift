import Foundation

/// Pre-fills the "log a meal" screen so a typical day takes one tap.
public struct AttendanceSuggestion: Equatable, Sendable {
    /// Members to pre-select, in list order.
    public let attendeeIds: [String]
    /// Suggested total for the meal (per-person price × attendees), if known.
    public let total: Money?
    /// Why these attendees were chosen — shown as a hint under the list.
    public let reason: Reason

    public enum Reason: Equatable, Sendable {
        /// Same people as the last time this meal type was logged.
        case sameAsLastTime(Day)
        /// Members marked as "usually attends".
        case defaultAttendees
    }
}

public enum AttendanceSuggester {
    /// - Parameters:
    ///   - mealType: the selected meal type, if any.
    ///   - members: the list's members.
    ///   - records: the list's past meals (any order).
    ///   - participants: participants of those meals.
    public static func suggest(
        mealType: MealType?,
        members: [Member],
        records: [MealRecord],
        participants: [Participant]
    ) -> AttendanceSuggestion {
        let active = members.filter(\.isActive)
        let activeIds = Set(active.map(\.id))

        var attendees: [String] = active.filter(\.isDefaultAttendee).map(\.id)
        var reason = AttendanceSuggestion.Reason.defaultAttendees
        var lastPerPerson: Money?

        if let mealType,
           let last = records
            .filter({ $0.mealTypeId == mealType.id })
            .max(by: { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }) {
            let lastParticipants = participants.filter { $0.recordId == last.id }
            let lastIds = Set(lastParticipants.filter { !$0.isGuest }.compactMap(\.memberId))
            let stillHere = active.map(\.id).filter { lastIds.contains($0) && activeIds.contains($0) }
            if !stillHere.isEmpty {
                attendees = stillHere
                reason = .sameAsLastTime(last.day)
            }
            if !lastParticipants.isEmpty && last.splitMode == .equal {
                // Guests count as people when working out the usual price per person.
                lastPerPerson = SplitCalculator.perPerson(last.totalAmount, attendeeCount: lastParticipants.count)
            }
        }

        let perPerson: Money?
        if let price = mealType?.defaultPrice, price.isPositive {
            perPerson = price
        } else {
            perPerson = lastPerPerson
        }

        let total = perPerson.map { $0 * attendees.count }
        return AttendanceSuggestion(attendeeIds: attendees,
                                    total: (total?.isPositive ?? false) ? total : nil,
                                    reason: reason)
    }
}
