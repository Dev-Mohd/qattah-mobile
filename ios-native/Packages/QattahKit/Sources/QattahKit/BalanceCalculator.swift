import Foundation

/// One member's position in a list.
public struct MemberBalance: Identifiable, Hashable, Sendable {
    public var id: String { member.id }
    public let member: Member
    public let openingBalance: Money
    /// Sum of the member's shares in meals.
    public let spent: Money
    /// Sum of the member's payments.
    public let paid: Money
    public let mealCount: Int

    /// Positive = the member owes money. Negative = the member has credit.
    public var net: Money { openingBalance + spent - paid }

    public var status: Status {
        if net.isPositive { return .owes }
        if net.isNegative { return .credit }
        return .settled
    }

    public enum Status: Sendable {
        case owes, credit, settled
    }
}

/// Shares that can no longer be attributed to a current member
/// (the member was deleted, or several members share the same name).
public struct UnassignedShare: Hashable, Sendable {
    public let memberName: String
    public let amount: Money
}

public struct ListBalances: Sendable {
    public let members: [MemberBalance]
    public let unassigned: [UnassignedShare]

    public var totalOwed: Money { members.map(\.net).filter(\.isPositive).sum() }
    public var totalCredit: Money { members.map(\.net).filter(\.isNegative).sum().magnitude }
    public var totalSpent: Money { members.map(\.spent).sum() + unassigned.map(\.amount).sum() }
    public var totalPaid: Money { members.map(\.paid).sum() }
}

public enum BalanceCalculator {
    /// Computes every member's balance.
    ///
    /// Attribution rules (fixing the Flutter version, which added shares by
    /// *name* on top of shares by *id*, double-counting people with the same name):
    /// 1. A share with a `memberId` belongs to that member only.
    /// 2. A share without a `memberId` (old data or deleted member) is given to
    ///    the member with the same name **only if exactly one** member has
    ///    that name. Otherwise it is reported in `unassigned`.
    /// 3. Shares of records that no longer exist are ignored.
    public static func balances(
        members: [Member],
        records: [MealRecord],
        participants: [Participant],
        payments: [Payment]
    ) -> ListBalances {
        let recordIds = Set(records.map(\.id))
        let memberIds = Set(members.map(\.id))
        let membersByName = Dictionary(grouping: members, by: { normalize($0.name) })

        var spent: [String: Money] = [:]
        var mealsAttended: [String: Set<String>] = [:]
        var unassigned: [String: Money] = [:]

        for participant in participants where recordIds.contains(participant.recordId) {
            if let owner = resolveOwner(memberId: participant.memberId, name: participant.memberName,
                                        memberIds: memberIds, membersByName: membersByName) {
                spent[owner, default: .zero] += participant.share
                // A guest's share goes to the host but is not a meal the host attended twice.
                if !participant.isGuest {
                    mealsAttended[owner, default: []].insert(participant.recordId)
                }
            } else {
                unassigned[participant.memberName, default: .zero] += participant.share
            }
        }

        var paid: [String: Money] = [:]
        for payment in payments {
            if let owner = resolveOwner(memberId: payment.memberId, name: payment.memberName,
                                        memberIds: memberIds, membersByName: membersByName) {
                paid[owner, default: .zero] += payment.amount
            } else {
                unassigned[payment.memberName, default: .zero] -= payment.amount
            }
        }

        let rows = members.map { member in
            MemberBalance(
                member: member,
                openingBalance: member.openingBalance,
                spent: spent[member.id] ?? .zero,
                paid: paid[member.id] ?? .zero,
                mealCount: mealsAttended[member.id]?.count ?? 0
            )
        }

        let leftovers = unassigned
            .filter { !$0.value.isZero }
            .map { UnassignedShare(memberName: $0.key, amount: $0.value) }
            .sorted { $0.memberName < $1.memberName }

        return ListBalances(members: rows, unassigned: leftovers)
    }

    private static func resolveOwner(memberId: String?, name: String, memberIds: Set<String>,
                                     membersByName: [String: [Member]]) -> String? {
        if let memberId, !memberId.isEmpty {
            return memberIds.contains(memberId) ? memberId : nil
        }
        let candidates = membersByName[normalize(name)] ?? []
        return candidates.count == 1 ? candidates[0].id : nil
    }

    private static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
