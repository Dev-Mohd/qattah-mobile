import SwiftUI
import Charts
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
    @State private var ledgerMember: Member?
    @State private var editingList: QattahList?
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
                BalancesSection(snapshot: snapshot, balances: balances,
                                onPay: { paymentMember = $0 }, onOpen: { ledgerMember = $0 })
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
                    editingList = snapshot.list
                } label: {
                    Label("تعديل القائمة", systemImage: "pencil")
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
        .sheet(item: $ledgerMember) { member in
            MemberLedgerView(listId: snapshot.list.id, memberId: member.id)
        }
        .sheet(item: $paymentMember) { member in
            AddPaymentView(member: member,
                           balance: balances.members.first { $0.id == member.id })
        }
        .sheet(item: $editingList) { list in
            ListEditorView(list: list)
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
    let onOpen: (Member) -> Void
    @State private var remindingAll = false
    @State private var showingSettlement = false
    @State private var showingPaste = false

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        QuickAction(title: "خطة التسوية", symbol: "arrow.left.arrow.right") { showingSettlement = true }
                        QuickAction(title: "من رسالة البنك", symbol: "text.viewfinder") { showingPaste = true }
                        if balances.members.contains(where: { $0.status == .owes }) {
                            QuickAction(title: "ذكّر الكل", symbol: "bell.badge") { remindingAll = true }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if chartRows.count > 1 {
                Section("من عليه ومن له") {
                    BalancesChart(rows: chartRows)
                        .frame(height: CGFloat(chartRows.count) * 30 + 16)
                        .padding(.vertical, 6)
                }
            }

            Section {
                ForEach(sortedRows) { row in
                    BalanceRow(row: row, listName: snapshot.list.name,
                               onPay: { onPay(row.member) }, onOpen: { onOpen(row.member) })
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
                Text("اضغط على العضو لعرض سداداته ووجباته، واسحب لتسجيل سداد أو إرسال تذكير")
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
        .sheet(isPresented: $showingSettlement) { SettlementView(snapshot: snapshot) }
        .sheet(isPresented: $showingPaste) { PasteBankMessageView(snapshot: snapshot) }
        .sheet(isPresented: $remindingAll) {
            RemindAllView(snapshot: snapshot,
                          debtors: balances.members.filter { $0.status == .owes }.sorted { $0.net > $1.net })
        }
    }

    private var chartRows: [MemberBalance] {
        sortedRows.filter { !$0.net.isZero }.prefix(10).map { $0 }
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
            MoneyText(money: money, font: .headline, weight: .bold)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: money.riyals))
                .animation(.snappy, value: money)
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
    let onOpen: () -> Void
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
        .onTapGesture(perform: onOpen)
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
    @State private var lastDeleted: (MealRecord, [Participant], [OrderLine], [Payment])?
    @Environment(Toaster.self) private var toaster
    @State private var query = ""
    @State private var memberFilter: String?

    /// Meals matching the search text (meal name, note, attendee or guest name) and the member filter.
    private var filteredRecords: [MealRecord] {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()
        return snapshot.records.filter { record in
            let people = snapshot.participants(of: record)
            if let memberFilter, !people.contains(where: { $0.memberId == memberFilter }) { return false }
            guard !text.isEmpty else { return true }
            let haystack = ([record.mealName, record.note, record.day.description]
                            + people.map(\.memberName) + people.compactMap(\.guestName))
                .joined(separator: " ").lowercased()
            return haystack.contains(text)
        }
    }

    var body: some View {
        List {
            if snapshot.records.isEmpty {
                ContentUnavailableView("لا توجد وجبات بعد", systemImage: "fork.knife",
                                       description: Text("اضغط «سجّل وجبة اليوم» للبدء"))
            } else if filteredRecords.isEmpty {
                ContentUnavailableView.search(text: query)
            }
            if memberFilter != nil || !query.isEmpty, !filteredRecords.isEmpty {
                Section {
                    HStack {
                        Text("\(filteredRecords.count) وجبة")
                        Spacer()
                        MoneyText(money: filteredRecords.map(\.totalAmount).sum(), weight: .semibold)
                    }
                    .font(.subheadline)
                }
            }
            ForEach(groupedByMonth, id: \.key) { month, records in
                Section(month) {
                    ForEach(records) { record in
                        MealRow(record: record, participants: snapshot.participants(of: record),
                                payer: snapshot.billPayment(of: record)?.memberName)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = record }
                            .contextMenu {
                                Button { editing = record } label: { Label("تعديل", systemImage: "pencil") }
                                Button { repeatToday(record) } label: {
                                    Label("كرّرها اليوم", systemImage: "arrow.clockwise")
                                }
                                .disabled(record.day == .today())
                                Divider()
                                Button(role: .destructive) { delete(record) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { repeatToday(record) } label: {
                                    Label("كرّر اليوم", systemImage: "arrow.clockwise")
                                }
                                .tint(.qattahAccent)
                            }
                            .swipeActions {
                                Button(role: .destructive) { delete(record) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "ابحث باسم وجبة أو عضو")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Picker("تصفية حسب العضو", selection: $memberFilter) {
                    Text("كل الأعضاء").tag(String?.none)
                    ForEach(snapshot.members) { member in
                        Text(member.name).tag(Optional(member.id))
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
        Dictionary(grouping: filteredRecords, by: \.day.monthKey)
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    private func delete(_ record: MealRecord) {
        let participants = snapshot.participants(of: record)
        let lines = snapshot.orderLines(of: record)
        let payments = snapshot.payments.filter { $0.recordId == record.id }
        Task {
            try? await store.deleteMeal(id: record.id)
            lastDeleted = (record, participants, lines, payments)
            try? await Task.sleep(for: .seconds(5))
            if lastDeleted?.0.id == record.id { lastDeleted = nil }
        }
    }

    /// Logs the same meal again today: same people, same split (and the same
    /// order for itemized meals). The bill payer is not copied.
    private func repeatToday(_ record: MealRecord) {
        let attendeeIds = Set(snapshot.participants(of: record).filter { !$0.isGuest }.compactMap(\.memberId))
        let attendees = snapshot.members.filter { attendeeIds.contains($0.id) && $0.isActive }
        guard !attendees.isEmpty else { return }
        var copy = record
        copy.id = UUID().uuidString.lowercased()
        copy.day = .today()
        copy.createdAt = .now
        copy.note = ""
        let lines = snapshot.orderLines(of: record).map {
            OrderLine(recordId: copy.id, memberId: $0.memberId, itemName: $0.itemName,
                      unitPrice: $0.unitPrice, quantity: $0.quantity)
        }
        let guests = snapshot.guests(of: record)
        Task {
            if record.splitMode == .items {
                try? await store.saveItemizedMeal(copy, attendees: attendees, lines: lines, extras: record.extras)
            } else {
                try? await store.saveMeal(copy, attendees: attendees, guests: guests)
            }
            Haptics.success()
            toaster.show("كُرّرت \(record.mealName) اليوم ✓", symbol: "arrow.clockwise.circle.fill")
        }
    }

    private func undo() {
        guard let deleted = lastDeleted else { return }
        lastDeleted = nil
        Task { try? await store.restoreMeal(deleted.0, participants: deleted.1, lines: deleted.2, payments: deleted.3) }
    }
}

private struct MealRow: View {
    let record: MealRecord
    let participants: [Participant]
    var payer: String?

    private var details: String {
        let members = participants.filter { !$0.isGuest }.count
        let guests = participants.filter(\.isGuest).count
        var parts = [record.day.description, "\(members) حاضر"]
        if guests > 0 { parts.append("\(guests) ضيف") }
        if record.splitMode == .items { parts.append("حسب الطلب") }
        if let payer { parts.append("دفع \(payer)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.mealName).font(.body.weight(.medium))
                Text(details)
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

/// Horizontal bars: debts to one side (red), credits to the other (green).
private struct BalancesChart: View {
    let rows: [MemberBalance]
    @State private var appeared = false

    var body: some View {
        Chart(rows) { row in
            BarMark(x: .value("الرصيد", appeared ? row.net.riyals : 0),
                    y: .value("العضو", row.member.name))
                .foregroundStyle(row.net.isPositive ? Color.owes.gradient : Color.credit.gradient)
                .cornerRadius(6)
                .annotation(position: row.net.isPositive ? .trailing : .leading, spacing: 4) {
                    Text(MoneyFormatter.number(row.net.magnitude))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
        }
        .chartXAxis(.hidden)
        .chartLegend(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
        .accessibilityLabel("رسم بياني للأرصدة")
    }
}

/// Capsule shortcut button under the balances summary.
private struct QuickAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.qattahAccent.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.qattahAccent)
        }
        .buttonStyle(PressableCardStyle())
    }
}
