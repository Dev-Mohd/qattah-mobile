import Foundation
import GRDB
import WidgetKit
import QattahKit

/// Keeps the widget's summary file up to date and saves meals queued from the widget.
enum WidgetSync {
    /// Saves meals tapped in the widget. Skips a queued meal if the same
    /// meal (list + meal type/name + day) was already logged, e.g. in the app.
    /// Returns how many meals were saved.
    @discardableResult
    static func applyPendingLogs(store: QattahStore) async -> Int {
        let pending = SharedStore.readPending()
        guard !pending.isEmpty else { return 0 }

        var handled = Set<String>()
        var saved = 0
        for log in pending {
            defer { handled.insert(log.id) }
            guard let snapshot = try? store.snapshot(listId: log.listId),
                  let day = Day(log.day) else { continue }

            let alreadyLogged = snapshot.records.contains { record in
                record.day == day && (record.mealTypeId == log.mealTypeId || record.mealName == log.mealName)
            }
            guard !alreadyLogged else { continue }

            let attendees = snapshot.members.filter { log.attendeeIds.contains($0.id) }
            guard !attendees.isEmpty, log.totalHalalas > 0 else { continue }

            let record = MealRecord(listId: log.listId, mealTypeId: log.mealTypeId, mealName: log.mealName,
                                    day: day, totalAmount: Money(halalas: log.totalHalalas),
                                    note: "سُجّلت من الودجت", createdAt: log.createdAt)
            do {
                try await store.saveMeal(record, attendees: attendees)
                saved += 1
            } catch {
                handled.remove(log.id) // keep it for the next attempt
            }
        }
        SharedStore.removePending(ids: handled)
        return saved
    }

    /// Rebuilds the widget summary from the database and reloads widgets.
    static func refresh(store: QattahStore) {
        guard let lists = try? store.database.writer.read({ db in
            try QattahStore.fetchSummaries(db).compactMap { summary in
                try QattahStore.fetchSnapshot(db, listId: summary.list.id)
            }
        }) else { return }

        let widgetLists = lists.map(makeWidgetList)
        SharedStore.writeSnapshot(WidgetSnapshot(lists: widgetLists, updatedAt: .now))
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func makeWidgetList(_ snapshot: ListSnapshot) -> WidgetList {
        let balances = snapshot.balances
        let debtors = balances.members
            .filter { $0.net.isPositive }
            .sorted { $0.net > $1.net }
            .prefix(3)
            .map { WidgetList.Debtor(name: $0.member.name, halalas: $0.net.halalas) }

        let suggestion = QuickLogPlanner.plan(for: snapshot)

        return WidgetList(id: snapshot.list.id,
                          name: snapshot.list.name,
                          colorHex: snapshot.list.color,
                          totalOwedHalalas: balances.totalOwed.halalas,
                          topDebtors: Array(debtors),
                          lastMealDay: snapshot.records.map(\.day).max()?.description,
                          quickLog: suggestion)
    }
}

/// Decides what "log today's meal" means without asking anything:
/// the meal type for the time of day, the usual attendees and the usual price.
enum QuickLogPlanner {
    static func plan(for snapshot: ListSnapshot, now: Date = .now) -> WidgetList.QuickLog? {
        let mealType = likelyMealType(snapshot.mealTypes, now: now)
        let suggestion = AttendanceSuggester.suggest(mealType: mealType, members: snapshot.members,
                                                     records: snapshot.records, participants: snapshot.participants)
        guard !suggestion.attendeeIds.isEmpty, let total = suggestion.total, total.isPositive else { return nil }
        return WidgetList.QuickLog(mealTypeId: mealType?.id,
                                   mealName: mealType?.name ?? "وجبة",
                                   attendeeIds: suggestion.attendeeIds,
                                   totalHalalas: total.halalas)
    }

    /// Before 11:00 → first meal type (usually breakfast); later → second, if any.
    static func likelyMealType(_ types: [MealType], now: Date = .now) -> MealType? {
        guard !types.isEmpty else { return nil }
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 11 && types.count > 1 ? types[1] : types[0]
    }
}
