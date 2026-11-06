import SwiftUI
import Charts
import GRDB
import QattahKit

/// Home screen: a "today" dashboard and a card per list.
struct ListsView: View {
    @Environment(\.store) private var store
    @State private var summaries: [ListSummary] = []
    @State private var loaded = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var editingList: QattahList?
    @State private var path: [String] = []
    @State private var pendingDelete: ListSummary?
    @State private var logMealSnapshot: ListSnapshot?
    @State private var appeared = false

    private var totalOwed: Money { summaries.map(\.totalOwed).sum() }
    private var monthSpent: Money { summaries.map(\.monthSpent).sum() }
    private var monthMeals: Int { summaries.map(\.monthMeals).reduce(0, +) }

    /// The list most likely to get today's meal: most recently used, not logged today.
    private var suggestedList: ListSummary? {
        let distantPast = Day(year: 1970, month: 1, day: 1)
        return summaries
            .filter { !$0.loggedToday && $0.memberCount > 0 }
            .max { ($0.lastMealDay ?? distantPast) < ($1.lastMealDay ?? distantPast) }
    }

    private var allLoggedToday: Bool {
        suggestedList == nil && summaries.contains(where: \.loggedToday)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if loaded && summaries.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 18) {
                        TodayCard(totalOwed: totalOwed, monthSpent: monthSpent, monthMeals: monthMeals,
                                  suggested: suggestedList, allLoggedToday: allLoggedToday) { summary in
                            openLogMeal(summary.list.id)
                        }
                        .modifier(AppearEffect(appeared: appeared, delay: 0))

                        HStack {
                            Text("قوائمي").font(.title3.bold())
                            Spacer()
                            Button {
                                editingList = QattahList(name: "")
                            } label: {
                                Label("قائمة جديدة", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .padding(.horizontal, 4)

                        ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                            NavigationLink(value: summary.list.id) {
                                ListCard(summary: summary)
                            }
                            .buttonStyle(PressableCardStyle())
                            .contextMenu { contextMenu(for: summary) }
                            .modifier(AppearEffect(appeared: appeared, delay: 0.06 * Double(index + 1)))
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationDestination(for: String.self) { listId in
                ListDetailView(listId: listId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("الإعدادات", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingList = QattahList(name: "")
                    } label: {
                        Label("قائمة جديدة", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(item: $editingList) { list in
                ListEditorView(list: list) { saved, isNew in
                    if isNew { path.append(saved.id) } // open the new list straight away
                }
            }
            .sheet(item: Binding(get: { logMealSnapshot.map(IdentifiedSnapshot.init) },
                                 set: { logMealSnapshot = $0?.snapshot })) { item in
                LogMealView(snapshot: item.snapshot)
            }
            .onOpenURL { url in
                // From the widget: qattah://list/<id>
                guard url.scheme == "qattah", url.host == "list" else { return }
                showingSettings = false
                path = [url.lastPathComponent]
            }
            .confirmationDialog("سيتم حذف القائمة «\(pendingDelete?.list.name ?? "")» مع كل أعضائها ووجباتها وسداداتها",
                                isPresented: .constant(pendingDelete != nil), titleVisibility: .visible) {
                Button("حذف القائمة", role: .destructive) {
                    if let id = pendingDelete?.list.id {
                        Task { try? await store.deleteList(id: id) }
                    }
                    pendingDelete = nil
                }
                Button("إلغاء", role: .cancel) { pendingDelete = nil }
            }
            .alert("حدث خطأ", isPresented: .constant(errorMessage != nil)) {
                Button("حسناً") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            do {
                for try await value in store.observeSummaries() {
                    withAnimation(.snappy) {
                        summaries = value
                        loaded = true
                    }
                    if !appeared {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var greeting: String {
        Calendar.current.component(.hour, from: .now) < 12 ? "صباح الخير ☀️" : "مساء الخير 🌙"
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            QattahLogoMark(size: 110)
            Text("ابدأ أول قطّة").font(.title2.bold())
            Text("أنشئ قائمة لفطور الدوام أو غداء الفريق، أضف الزملاء، وسجّل الوجبات بلمسة")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                editingList = QattahList(name: "")
            } label: {
                Label("إنشاء قائمة", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func contextMenu(for summary: ListSummary) -> some View {
        Button {
            openLogMeal(summary.list.id)
        } label: {
            Label("سجّل وجبة", systemImage: "plus.circle")
        }
        .disabled(summary.memberCount == 0)
        Button {
            editingList = summary.list
        } label: {
            Label("تعديل القائمة", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            pendingDelete = summary
        } label: {
            Label("حذف", systemImage: "trash")
        }
    }

    private func openLogMeal(_ listId: String) {
        Haptics.tap()
        logMealSnapshot = try? store.snapshot(listId: listId)
    }
}

private struct IdentifiedSnapshot: Identifiable {
    let snapshot: ListSnapshot
    var id: String { snapshot.list.id }
}

// MARK: - Today card

private struct TodayCard: View {
    let totalOwed: Money
    let monthSpent: Money
    let monthMeals: Int
    let suggested: ListSummary?
    let allLoggedToday: Bool
    let onLog: (ListSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("المستحق في كل القوائم")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(MoneyFormatter.number(totalOwed))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: totalOwed.riyals))
                        Text(MoneyFormatter.riyalSign)
                            .font(.custom("saudi_riyalregular", size: 24, relativeTo: .title))
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                }
                Spacer()
                QattahLogoMark(size: 54).opacity(0.9)
            }

            HStack(spacing: 12) {
                MiniStat(title: "مصروف الشهر", value: MoneyFormatter.plain(monthSpent))
                MiniStat(title: "وجبات الشهر", value: "\(monthMeals)")
            }

            if let suggested {
                Button {
                    onLog(suggested)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("سجّل وجبة اليوم").font(.headline)
                            Text(suggested.list.name).font(.caption).opacity(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").font(.caption.bold())
                    }
                    .padding(14)
                    .foregroundStyle(Color(red: 0.02, green: 0.31, blue: 0.21))
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(PressableCardStyle())
            } else if allLoggedToday {
                Label("سُجّلت وجبات اليوم، يومك سعيد", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: allLoggedToday)
            }
        }
        .padding(20)
        .background(
            ZStack {
                LinearGradient(colors: [Color(red: 0.02, green: 0.37, blue: 0.27),
                                        Color(red: 0.01, green: 0.18, blue: 0.14)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color(red: 0.06, green: 0.73, blue: 0.51).opacity(0.35))
                    .frame(width: 220)
                    .blur(radius: 60)
                    .offset(x: 120, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(red: 0.02, green: 0.37, blue: 0.27).opacity(0.35), radius: 18, y: 10)
    }
}

private struct MiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - List card

private struct ListCard: View {
    let summary: ListSummary

    var body: some View {
        let color = Color(hex: summary.list.color)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(summary.list.icon ?? "🍽️")
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.list.name).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if summary.loggedToday {
                    Label("اليوم", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.credit)
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.totalOwed.isPositive ? "مستحق" : "الحساب")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if summary.totalOwed.isPositive {
                        MoneyText(money: summary.totalOwed, font: .title3, weight: .bold)
                            .foregroundStyle(Color.owes)
                    } else {
                        Text("مسدّد ✓").font(.title3.bold()).foregroundStyle(Color.credit)
                    }
                    if let debtor = summary.topDebtor {
                        Text("الأعلى: \(debtor)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Sparkline(values: summary.recentDaily, color: color)
                    .frame(width: 120, height: 44)
            }
        }
        .padding(16)
        .padding(.leading, 4)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .leading) {
            // Accent strip on the start edge (the right side in Arabic).
            UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, style: .continuous)
                .fill(color)
                .frame(width: 6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private var subtitle: String {
        var parts = ["\(summary.memberCount) أعضاء"]
        if summary.monthMeals > 0 { parts.append("\(summary.monthMeals) وجبة هذا الشهر") }
        if let last = summary.lastMealDay, !summary.loggedToday { parts.append("آخر وجبة \(last)") }
        return parts.joined(separator: " · ")
    }
}

/// Spending over the last 14 days as small bars.
struct Sparkline: View {
    let values: [Money]
    let color: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            BarMark(x: .value("اليوم", item.offset), y: .value("المبلغ", item.element.riyals))
                .foregroundStyle(color.gradient)
                .cornerRadius(2)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("مصروف آخر أسبوعين")
    }
}

// MARK: - Shared effects

/// Cards slide up and fade in, one after another.
struct AppearEffect: ViewModifier {
    let appeared: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 24)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

/// Slight shrink while pressed.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - List editor

/// Create or edit a list: name, icon and color.
struct ListEditorView: View {
    @State var list: QattahList
    var onSaved: (QattahList, Bool) -> Void = { _, _ in }

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isNew = false

    static let colors = ["#10B981", "#0EA5E9", "#6366F1", "#F59E0B", "#EF4444", "#EC4899", "#8B5CF6", "#14B8A6"]
    static let icons = ["🍽️", "🍳", "☕️", "🥙", "🍕", "🥗", "🏢", "🏖️", "🚗", "🎉"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(list.icon ?? "🍽️")
                            .font(.largeTitle)
                            .frame(width: 64, height: 64)
                            .background(Color(hex: list.color).opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
                        TextField("اسم القائمة (مثال: فطور الدوام)", text: $list.name)
                            .font(.title3.weight(.semibold))
                    }
                }

                Section("الأيقونة") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { icon in
                            Text(icon)
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill((list.icon ?? "🍽️") == icon
                                                          ? Color(hex: list.color).opacity(0.25) : .clear))
                                .onTapGesture {
                                    Haptics.tap()
                                    withAnimation(.spring) { list.icon = icon }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("اللون") {
                    HStack {
                        ForEach(Self.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if list.color == hex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .scaleEffect(list.color == hex ? 1.15 : 1)
                                .onTapGesture {
                                    Haptics.tap()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { list.color = hex }
                                }
                            if hex != Self.colors.last { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(isNew ? "قائمة جديدة" : "تعديل القائمة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "إنشاء" : "حفظ") { save() }
                        .fontWeight(.semibold)
                        .disabled(list.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNew = list.name.isEmpty
                if list.icon == nil { list.icon = "🍽️" }
            }
        }
    }

    private func save() {
        var saved = list
        saved.name = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasNew = isNew
        Task {
            try? await store.saveList(saved)
            Haptics.success()
            dismiss()
            onSaved(saved, wasNew)
        }
    }
}
