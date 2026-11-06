import AppIntents
import WidgetKit
import QattahKit

/// A list, as offered to the widget configuration and to Siri / Shortcuts.
struct ListEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "قائمة")
    static let defaultQuery = ListEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ list: WidgetList) {
        self.init(id: list.id, name: list.name)
    }
}

struct ListEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [String]) async throws -> [ListEntity] {
        SharedStore.readSnapshot().lists.filter { identifiers.contains($0.id) }.map(ListEntity.init)
    }

    func suggestedEntities() async throws -> [ListEntity] {
        SharedStore.readSnapshot().lists.map(ListEntity.init)
    }

    func allEntities() async throws -> [ListEntity] {
        try await suggestedEntities()
    }

    func defaultResult() async -> ListEntity? {
        SharedStore.readSnapshot().lists.first.map(ListEntity.init)
    }
}

/// Widget configuration: which list to show.
struct SelectListIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "اختر القائمة"
    static let description = IntentDescription("القائمة التي يعرضها الودجت")

    @Parameter(title: "القائمة")
    var list: ListEntity?

    init() {}

    init(list: ListEntity?) {
        self.list = list
    }
}

/// The widget's "log today's meal" button.
///
/// Runs inside the widget extension, which cannot open the encrypted
/// database. It queues the meal; the app saves it on its next run and the
/// widget shows it as logged right away.
struct QuickLogMealIntent: AppIntent {
    static let title: LocalizedStringResource = "سجّل وجبة اليوم"
    static let isDiscoverable = false

    @Parameter(title: "القائمة")
    var listId: String

    init() {}

    init(listId: String) {
        self.listId = listId
    }

    func perform() async throws -> some IntentResult {
        var snapshot = SharedStore.readSnapshot()
        guard let index = snapshot.lists.firstIndex(where: { $0.id == listId }),
              let quick = snapshot.lists[index].quickLog else {
            return .result()
        }
        let today = Day.today()
        guard !snapshot.lists[index].loggedToday(today: today) else { return .result() }

        SharedStore.appendPending(PendingMealLog(
            id: UUID().uuidString.lowercased(),
            listId: listId,
            mealTypeId: quick.mealTypeId,
            mealName: quick.mealName,
            day: today.description,
            attendeeIds: quick.attendeeIds,
            totalHalalas: quick.totalHalalas,
            createdAt: .now
        ))

        // Optimistic update so the widget shows "✓" immediately. Balances are
        // recomputed by the app when it saves the meal.
        snapshot.lists[index].lastMealDay = today.description
        snapshot.updatedAt = .now
        SharedStore.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
