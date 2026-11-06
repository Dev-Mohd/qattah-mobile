import AppIntents
import QattahKit

// Siri & Shortcuts. These intents live in the app target, so they run in the
// app's process (launched in the background if needed) and can use the
// encrypted database directly.

/// "سجّل الفطور في قطّه" — logs today's meal with the usual attendees and price.
struct LogMealIntent: AppIntent {
    static let title: LocalizedStringResource = "سجّل وجبة اليوم"
    static let description = IntentDescription("يسجّل وجبة اليوم بنفس الحاضرين والسعر المعتاد")

    @Parameter(title: "القائمة")
    var list: ListEntity

    @Parameter(title: "المبلغ الكلي", description: "اتركه فارغاً لاستخدام السعر المعتاد")
    var total: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("سجّل وجبة اليوم في \(\.$list)") {
            \.$total
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = try IntentDatabase.store()
        guard let snapshot = try store.snapshot(listId: list.id) else {
            throw IntentError.message("لم أجد القائمة")
        }

        let today = Day.today()
        let mealType = QuickLogPlanner.likelyMealType(snapshot.mealTypes)
        if snapshot.records.contains(where: { $0.day == today && ($0.mealTypeId == mealType?.id) }) {
            return .result(dialog: "سبق تسجيل \(mealType?.name ?? "وجبة") اليوم في \(snapshot.list.name)")
        }

        let suggestion = AttendanceSuggester.suggest(mealType: mealType, members: snapshot.members,
                                                     records: snapshot.records, participants: snapshot.participants)
        let attendees = snapshot.members.filter { suggestion.attendeeIds.contains($0.id) }
        guard !attendees.isEmpty else {
            throw IntentError.message("لا يوجد أعضاء في القائمة. افتح قطّه وأضف الأعضاء أولاً")
        }
        guard let amount = total.map({ Money(riyals: $0) }) ?? suggestion.total, amount.isPositive else {
            throw IntentError.message("لا يوجد سعر معتاد لهذه الوجبة. قل المبلغ أو حدّد السعر في التطبيق")
        }

        let record = MealRecord(listId: snapshot.list.id, mealTypeId: mealType?.id,
                                mealName: mealType?.name ?? "وجبة", day: today, totalAmount: amount,
                                note: "سُجّلت عبر Siri")
        try await store.saveMeal(record, attendees: attendees)
        WidgetSync.refresh(store: store)

        let perPerson = SplitCalculator.perPerson(amount, attendeeCount: attendees.count)
        return .result(dialog: """
            تم تسجيل \(record.mealName) في \(snapshot.list.name): \(attendees.count) حاضرين، \
            نصيب الشخص \(MoneyFormatter.plain(perPerson))
            """)
    }
}

/// "كم المستحق في قطّه؟"
struct BalancesIntent: AppIntent {
    static let title: LocalizedStringResource = "الأرصدة المستحقة"
    static let description = IntentDescription("يخبرك من عليه مبالغ وكم المجموع")

    @Parameter(title: "القائمة")
    var list: ListEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let store = try IntentDatabase.store()
        guard let snapshot = try store.snapshot(listId: list.id) else {
            throw IntentError.message("لم أجد القائمة")
        }
        let balances = snapshot.balances
        let owing = balances.members.filter { $0.net.isPositive }.sorted { $0.net > $1.net }
        let text: String
        if owing.isEmpty {
            text = "لا توجد مبالغ مستحقة في \(snapshot.list.name) ✅"
        } else {
            let names = owing.prefix(5)
                .map { "\($0.member.name) \(MoneyFormatter.plain($0.net))" }
                .joined(separator: "، ")
            text = "المستحق في \(snapshot.list.name) \(MoneyFormatter.plain(balances.totalOwed)): \(names)"
        }
        let message = ShareMessageBuilder.balancesMessage(listName: snapshot.list.name, balances: balances,
                                                          asOf: .today())
        return .result(value: message, dialog: "\(text)")
    }
}

struct QattahShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "سجّل وجبة في \(.applicationName)",
                "سجل وجبة اليوم في \(.applicationName)",
                "سجّل \(\.$list) في \(.applicationName)",
                "Log a meal in \(.applicationName)",
            ],
            shortTitle: "سجّل وجبة",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: BalancesIntent(),
            phrases: [
                "كم المستحق في \(.applicationName)",
                "مين عليه فلوس في \(.applicationName)",
                "أرصدة \(\.$list) في \(.applicationName)",
                "Who owes money in \(.applicationName)",
            ],
            shortTitle: "الأرصدة",
            systemImageName: "banknote"
        )
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): "\(text)"
        }
    }
}

/// Opens the database once per process for intents (the app may have been
/// launched in the background just to run one).
@MainActor
enum IntentDatabase {
    private static var cached: QattahStore?

    static func store() throws -> QattahStore {
        if let cached { return cached }
        let store = QattahStore(database: try AppDatabase.shared())
        cached = store
        return store
    }
}
