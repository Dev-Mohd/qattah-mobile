import SwiftUI
import GRDB
import QattahKit

struct ListDetailView: View {
    let listId: String

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @State private var snapshot: ListSnapshot?
    @State private var loaded = false
    @State private var tab: DetailTab = .balances
    @State private var showingLogMeal = false
    @State private var paymentMember: Member?
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    enum DetailTab: String, CaseIterable, Identifiable {
        case balances = "الأرصدة"
        case meals = "الوجبات"
        case report = "التقرير"
        case members = "الأعضاء"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let snapshot {
                content(snapshot)
            } else if loaded {
                ContentUnavailableView("القائمة غير موجودة", systemImage: "tray")
            } else {
                ProgressView()
            }
        }
        .navigationTitle(snapshot?.list.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                for try await value in store.observeList(id: listId) {
                    if !loaded, let value, value.members.isEmpty { tab = .members }
                    snapshot = value
                    loaded = true
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("حدث خطأ", isPresented: .constant(errorMessage != nil)) {
            Button("حسناً") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func content(_ snapshot: ListSnapshot) -> some View {
        let balances = snapshot.balances

        VStack(spacing: 0) {
            Picker("القسم", selection: $tab) {
                ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch tab {
            case .balances:
                BalancesSection(snapshot: snapshot, balances: balances) { paymentMember = $0 }
            case .meals:
                MealsSection(snapshot: snapshot)
            case .report:
                ReportView(snapshot: snapshot)
            case .members:
                MembersSection(snapshot: snapshot)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if tab != .report {
                logMealButton(snapshot)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: ShareMessageBuilder.balancesMessage(
                    listName: snapshot.list.name, balances: balances, asOf: .today(),
                    options: .init(payment: settings.paymentDetails))) {
                    Label("مشاركة الأرصدة", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    newName = snapshot.list.name
                    renaming = true
                } label: {
                    Label("تعديل الاسم", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("حذف القائمة", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingLogMeal) {
            LogMealView(snapshot: snapshot)
        }
        .sheet(item: $paymentMember) { member in
            AddPaymentView(member: member,
                           balance: balances.members.first { $0.id == member.id })
        }
        .alert("تعديل اسم القائمة", isPresented: $renaming) {
            TextField("الاسم", text: $newName)
            Button("حفظ") { rename(snapshot.list) }
            Button("إلغاء", role: .cancel) {}
        }
        .confirmationDialog("سيتم حذف القائمة «\(snapshot.list.name)» مع كل أعضائها ووجباتها وسداداتها",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("حذف القائمة", role: .destructive) { delete(snapshot.list) }
        }
    }

    private func logMealButton(_ snapshot: ListSnapshot) -> some View {
        let hasMembers = !snapshot.members.filter(\.isActive).isEmpty
        return Button {
            Haptics.tap()
            if hasMembers {
                showingLogMeal = true
            } else {
                tab = .members
            }
        } label: {
            Label(hasMembers ? "سجّل وجبة اليوم" : "أضف الأعضاء أولاً",
                  systemImage: hasMembers ? "plus.circle.fill" : "person.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func rename(_ list: QattahList) {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var updated = list
        updated.name = name
        Task { try? await store.saveList(updated) }
    }

    private func delete(_ list: QattahList) {
        Task {
            do {
                try await store.deleteList(id: list.id)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Balances

private struct BalancesSection: View {
    let snapshot: ListSnapshot
    let balances: ListBalances
    let onPay: (Member) -> Void
    @State private var remindingAll = false

    var body: some View {
        List {
            Section {
                HStack {
                    SummaryTile(title: "مستحق", money: balances.totalOwed, color: .owes)
                    SummaryTile(title: "رصيد دائن", money: balances.totalCredit, color: .credit)
                    SummaryTile(title: "مجموع المصروف", money: balances.totalSpent, color: .primary)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(sortedRows) { row in
                    BalanceRow(row: row, listName: snapshot.list.name) { onPay(row.member) }
                }
            } header: {
                HStack {
                    Text("الأعضاء")
                    Spacer()
                    if balances.members.contains(where: { $0.status == .owes }) {
                        Button {
                            remindingAll = true
                        } label: {
                            Label("ذكّر الكل", systemImage: "bell.badge")
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            } footer: {
                Text("اضغط على العضو لتسجيل سداد، أو اسحب لإرسال تذكير بالواتساب")
            }

            if !balances.unassigned.isEmpty {
                Section("مبالغ لأعضاء محذوفين") {
                    ForEach(balances.unassigned, id: \.memberName) { item in
                        HStack {
                            Text(item.memberName)
                            Spacer()
                            MoneyText(money: item.amount).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $remindingAll) {
            RemindAllView(listName: snapshot.list.name,
                          debtors: balances.members.filter { $0.status == .owes }.sorted { $0.net > $1.net })
        }
    }

    /// Debtors first (largest first), then settled, then creditors.
    private var sortedRows: [MemberBalance] {
        balances.members
            .filter { $0.member.isActive || !$0.net.isZero }
            .sorted { $0.net > $1.net }
    }
}

private struct SummaryTile: View {
    let title: String
    let money: Money
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            MoneyText(money: money, font: .headline, weight: .bold).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct BalanceRow: View {
    let row: MemberBalance
    let listName: String
    let onPay: () -> Void
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL

    private var reminder: String {
        ShareMessageBuilder.reminderMessage(listName: listName, balance: row, payment: settings.paymentDetails)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(row.member.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.member.name).font(.body.weight(.medium))
                Text("\(row.mealCount) وجبة")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(money: row.net.magnitude, font: .body, weight: .semibold)
                    .foregroundStyle(row.status.color)
                Text(row.status.label).font(.caption2).foregroundStyle(row.status.color)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPay)
        .swipeActions(edge: .leading) {
            Button(action: onPay) {
                Label("سداد", systemImage: "banknote")
            }
            .tint(.credit)
        }
        .swipeActions(edge: .trailing) {
            if let url = WhatsApp.url(phone: row.member.phone, text: reminder) {
                Button {
                    openURL(url)
                } label: {
                    Label("واتساب", systemImage: "message")
                }
                .tint(.green)
            }
            ShareLink(item: reminder) {
                Label("تذكير", systemImage: "bell")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Meals

private struct MealsSection: View {
    let snapshot: ListSnapshot
    @Environment(\.store) private var store
    @State private var editing: MealRecord?
    @State private var lastDeleted: (MealRecord, [Participant], [OrderLine])?

    var body: some View {
        List {
            if snapshot.records.isEmpty {
                ContentUnavailableView("لا توجد وجبات بعد", systemImage: "fork.knife",
                                       description: Text("اضغط «سجّل وجبة اليوم» للبدء"))
            }
            ForEach(groupedByMonth, id: \.key) { month, records in
                Section(month) {
                    ForEach(records) { record in
                        MealRow(record: record, participants: snapshot.participants(of: record))
                            .contentShape(Rectangle())
                            .onTapGesture { editing = record }
                            .swipeActions {
                                Button(role: .destructive) { delete(record) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .sheet(item: $editing) { record in
            LogMealView(snapshot: snapshot, editing: record)
        }
        .overlay(alignment: .bottom) {
            if let deleted = lastDeleted {
                UndoBanner(text: "حُذفت وجبة \(deleted.0.mealName)") { undo() }
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: lastDeleted?.0.id)
    }

    private var groupedByMonth: [(key: String, value: [MealRecord])] {
        Dictionary(grouping: snapshot.records, by: \.day.monthKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    private func delete(_ record: MealRecord) {
        let participants = snapshot.participants(of: record)
        let lines = snapshot.orderLines(of: record)
        Task {
            try? await store.deleteMeal(id: record.id)
            lastDeleted = (record, participants, lines)
            try? await Task.sleep(for: .seconds(5))
            if lastDeleted?.0.id == record.id { lastDeleted = nil }
        }
    }

    private func undo() {
        guard let deleted = lastDeleted else { return }
        lastDeleted = nil
        Task { try? await store.restoreMeal(deleted.0, participants: deleted.1, lines: deleted.2) }
    }
}

private struct MealRow: View {
    let record: MealRecord
    let participants: [Participant]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.mealName).font(.body.weight(.medium))
                Text("\(record.day.description) · \(participants.count) حاضر"
                     + (record.splitMode == .items ? " · حسب الطلب" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !record.note.isEmpty {
                    Text(record.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            MoneyText(money: record.totalAmount, weight: .semibold)
        }
    }
}

struct UndoBanner: View {
    let text: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(text).font(.subheadline)
            Spacer()
            Button("تراجع", action: onUndo).fontWeight(.semibold)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

// MARK: - Members

private struct MembersSection: View {
    let snapshot: ListSnapshot
    @Environment(\.store) private var store
    @State private var editingMember: Member?
    @State private var editingMealType: MealType?

    var body: some View {
        List {
            Section {
                ForEach(snapshot.members.filter(\.isActive)) { member in
                    Button { editingMember = member } label: {
                        HStack {
                            Text(member.emoji)
                            Text(member.name).foregroundStyle(.primary)
                            Spacer()
                            if member.isDefaultAttendee {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.credit)
                                    .accessibilityLabel("يحضر عادة")
                            }
                        }
                    }
                }
                Button {
                    editingMember = Member(listId: snapshot.list.id, name: "")
                } label: {
                    Label("إضافة عضو", systemImage: "person.badge.plus")
                }
            } header: {
                Text("الأعضاء")
            } footer: {
                Text("✓ تعني أن العضو يُحدَّد تلقائياً عند تسجيل وجبة")
            }

            Section("أنواع الوجبات") {
                ForEach(snapshot.mealTypes) { type in
                    Button { editingMealType = type } label: {
                        HStack {
                            Text(type.name).foregroundStyle(.primary)
                            Spacer()
                            if type.defaultPrice.isPositive {
                                MoneyText(money: type.defaultPrice).foregroundStyle(.secondary)
                                Text("للشخص").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button {
                    editingMealType = MealType(listId: snapshot.list.id, name: "")
                } label: {
                    Label("إضافة نوع وجبة", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingMember) { MemberEditor(member: $0) }
        .sheet(item: $editingMealType) { MealTypeEditor(mealType: $0) }
    }
}

private struct MemberEditor: View {
    @State var member: Member
    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var openingText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("الاسم", text: $member.name)
                TextField("رمز تعبيري", text: $member.emoji)
                TextField("رقم الجوال للتذكير بالواتساب (اختياري)", text: Binding(
                    get: { member.phone ?? "" },
                    set: { member.phone = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                Toggle("يحضر عادة", isOn: $member.isDefaultAttendee)
                Section {
                    TextField("0", text: $openingText).keyboardType(.decimalPad)
                } header: {
                    Text("رصيد سابق")
                } footer: {
                    Text("مبلغ كان على العضو قبل استخدام التطبيق. اكتبه بالسالب إذا كان له.")
                }
                if !member.name.isEmpty {
                    Section {
                        Button("إزالة العضو", role: .destructive) {
                            Task { try? await store.removeMember(member); dismiss() }
                        }
                    } footer: {
                        Text("إذا كان للعضو وجبات أو سدادات سيُخفى فقط ويبقى حسابه محفوظاً.")
                    }
                }
            }
            .navigationTitle(member.name.isEmpty ? "عضو جديد" : member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .disabled(member.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                openingText = member.openingBalance.isZero ? "" : MoneyFormatter.number(member.openingBalance)
                    .replacingOccurrences(of: ",", with: "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        var updated = member
        updated.name = member.name.trimmingCharacters(in: .whitespaces)
        let negative = openingText.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        let amount = AmountParser.money(from: openingText.replacingOccurrences(of: "-", with: "")) ?? .zero
        updated.openingBalance = negative ? -amount : amount
        if updated.emoji.isEmpty { updated.emoji = "👤" }
        Task {
            try? await store.saveMember(updated)
            Haptics.success()
            dismiss()
        }
    }
}

private struct MealTypeEditor: View {
    @State var mealType: MealType
    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var priceText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("الاسم (فطور، غداء…)", text: $mealType.name)
                Section {
                    TextField("0", text: $priceText).keyboardType(.decimalPad)
                } header: {
                    Text("السعر المعتاد للشخص")
                } footer: {
                    Text("يُحسب المبلغ الكلي تلقائياً حسب عدد الحاضرين ويمكنك تعديله.")
                }
                if !mealType.name.isEmpty {
                    Button("حذف نوع الوجبة", role: .destructive) {
                        Task { try? await store.deleteMealType(id: mealType.id); dismiss() }
                    }
                }
            }
            .navigationTitle(mealType.name.isEmpty ? "نوع وجبة جديد" : mealType.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        var updated = mealType
                        updated.name = mealType.name.trimmingCharacters(in: .whitespaces)
                        updated.defaultPrice = AmountParser.money(from: priceText) ?? .zero
                        Task { try? await store.saveMealType(updated); dismiss() }
                    }
                    .disabled(mealType.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { priceText = AmountParser.text(from: mealType.defaultPrice) }
        }
        .presentationDetents([.medium])
    }
}
