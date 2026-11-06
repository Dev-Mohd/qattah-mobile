import WidgetKit
import SwiftUI
import AppIntents
import QattahKit

@main
struct QattahWidgetBundle: WidgetBundle {
    var body: some Widget {
        QattahListWidget()
    }
}

struct QattahListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "QattahList", intent: SelectListIntent.self, provider: Provider()) { entry in
            QattahWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("قطّه")
        .description("المستحق في القائمة وتسجيل وجبة اليوم بلمسة")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let list: WidgetList?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, list: .placeholder)
    }

    func snapshot(for configuration: SelectListIntent, in context: Context) async -> Entry {
        Entry(date: .now, list: resolve(configuration) ?? (context.isPreview ? .placeholder : nil))
    }

    func timeline(for configuration: SelectListIntent, in context: Context) async -> Timeline<Entry> {
        let entry = Entry(date: .now, list: resolve(configuration))
        // Refresh after midnight so "logged today" resets; the app also reloads on every change.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400)).addingTimeInterval(60)
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }

    private func resolve(_ configuration: SelectListIntent) -> WidgetList? {
        let lists = SharedStore.readSnapshot().lists
        if let id = configuration.list?.id, let match = lists.first(where: { $0.id == id }) {
            return match
        }
        return lists.first
    }
}

// MARK: - Views

struct QattahWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let list = entry.list {
                switch family {
                case .accessoryInline:
                    Text("\(list.name): \(MoneyFormatter.plain(list.totalOwed))")
                case .accessoryRectangular:
                    rectangular(list)
                case .systemMedium:
                    medium(list)
                default:
                    small(list)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                    Text("افتح قطّه وأنشئ قائمة").font(.caption).multilineTextAlignment(.center)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(entry.list.map { URL(string: "qattah://list/\($0.id)")! })
    }

    private func header(_ list: WidgetList) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color(widgetHex: list.colorHex)).frame(width: 8, height: 8)
            Text(list.name).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func owed(_ list: WidgetList, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("المستحق").font(.caption2).foregroundStyle(.secondary)
            Text(MoneyFormatter.plain(list.totalOwed))
                .font(font.weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
    }

    @ViewBuilder
    private func logButton(_ list: WidgetList) -> some View {
        if list.loggedToday() {
            Label("سُجّلت اليوم", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        } else if let quick = list.quickLog {
            Button(intent: QuickLogMealIntent(listId: list.id)) {
                Label("سجّل \(quick.mealName)", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        } else {
            Text("حدّد سعراً معتاداً للوجبة لتسجيلها من هنا")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func small(_ list: WidgetList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(list)
            owed(list, font: .title2)
            Spacer(minLength: 0)
            logButton(list)
        }
    }

    private func medium(_ list: WidgetList) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                header(list)
                owed(list, font: .title)
                Spacer(minLength: 0)
                logButton(list)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("الأعلى مديونية").font(.caption2).foregroundStyle(.secondary)
                if list.topDebtors.isEmpty {
                    Text("الكل مسدّد ✅").font(.caption)
                }
                ForEach(list.topDebtors, id: \.name) { debtor in
                    HStack {
                        Text(debtor.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(MoneyFormatter.number(Money(halalas: debtor.halalas)))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    }
                }
                Spacer(minLength: 0)
                if let quick = list.quickLog, !list.loggedToday() {
                    Text("\(quick.attendeeIds.count) حاضرين · \(MoneyFormatter.plain(Money(halalas: quick.totalHalalas)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func rectangular(_ list: WidgetList) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(list.name).font(.headline).lineLimit(1)
            Text("المستحق \(MoneyFormatter.plain(list.totalOwed))").font(.caption).monospacedDigit()
            Text(list.loggedToday() ? "✓ سُجّلت وجبة اليوم" : "لم تُسجَّل وجبة اليوم")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Color {
    init(widgetHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(cleaned, radix: 16) ?? 0x10B981
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

private extension WidgetList {
    static let placeholder = WidgetList(
        id: "placeholder", name: "فطور الدوام", colorHex: "#10B981", totalOwedHalalas: 12_500,
        topDebtors: [.init(name: "أحمد", halalas: 4_500), .init(name: "سعد", halalas: 3_000)],
        lastMealDay: nil,
        quickLog: .init(mealTypeId: nil, mealName: "فطور", attendeeIds: ["a", "b", "c", "d"], totalHalalas: 4_000)
    )
}
