import SwiftUI
import UIKit
import QattahKit

/// Log (or edit) a meal. Designed so a normal day is: open → tap «حفظ».
/// - Remembers who attended this meal type last time.
/// - Two ways to split: equally, or "each pays for what they ordered"
///   (with shared items and delivery/tax split in proportion).
/// - "Same order as last time" and a ready-to-send order for the restaurant.
/// - Shows each person's exact share before saving.
struct LogMealView: View {
    let snapshot: ListSnapshot
    var editing: MealRecord?

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    @State private var mealTypeId: String?
    @State private var day = Date.now
    @State private var attendees: Set<String> = []
    @State private var splitMode: MealRecord.SplitMode = .equal
    @State private var totalText = ""
    /// The last total the app filled in by itself. If the field differs, the user typed it.
    @State private var autoTotalText = ""
    @State private var lines: [OrderLine] = []
    @State private var extrasText = ""
    @State private var picking: PickTarget?
    @State private var guests: [Guest] = []
    @State private var addingGuest = false
    @State private var newGuestName = ""
    @State private var newGuestHost: String?
    /// Member who paid the restaurant (gets a linked payment). nil = not paid by a member.
    @State private var payerId: String?
    @State private var note = ""
    @State private var hint: String?
    @State private var saving = false
    @State private var didLoad = false
    @State private var copiedOrder = false

    /// Whose order the menu picker is adding to.
    enum PickTarget: Identifiable, Hashable {
        case member(String)
        case shared
        var id: String {
            switch self {
            case .member(let id): id
            case .shared: "shared"
            }
        }
        var memberId: String? {
            if case .member(let id) = self { return id }
            return nil
        }
    }

    private var activeMembers: [Member] {
        snapshot.members.filter { $0.isActive || attendees.contains($0.id) }
    }

    private var selectedType: MealType? {
        snapshot.mealTypes.first { $0.id == mealTypeId }
    }

    private var orderedAttendees: [Member] {
        activeMembers.filter { attendees.contains($0.id) }
    }

    private var extras: Money {
        let text = extrasText.trimmingCharacters(in: .whitespaces)
        let negative = text.hasPrefix("-")
        let value = AmountParser.money(from: text.replacingOccurrences(of: "-", with: "")) ?? .zero
        return negative ? -value : value
    }

    private var itemSplit: ItemSplitCalculator.Result {
        ItemSplitCalculator.split(lines: lines, attendeeIds: orderedAttendees.map(\.id), extras: extras)
    }

    private var total: Money {
        switch splitMode {
        case .equal: AmountParser.money(from: totalText) ?? .zero
        case .items: itemSplit.total
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection

                Section {
                    ForEach(activeMembers) { member in
                        AttendeeRow(member: member,
                                    isOn: attendees.contains(member.id),
                                    share: share(for: member),
                                    lines: splitMode == .items ? lines(for: member.id) : [],
                                    showsItems: splitMode == .items && attendees.contains(member.id),
                                    onToggle: { toggle(member) },
                                    onAddItem: { picking = .member(member.id) },
                                    onChangeQuantity: changeQuantity)
                    }
                } header: {
                    HStack {
                        Text("الحاضرون (\(attendees.count) من \(activeMembers.count))")
                        Spacer()
                        Button(attendees.count == activeMembers.count ? "إلغاء الكل" : "تحديد الكل") {
                            Haptics.tap()
                            attendees = attendees.count == activeMembers.count ? [] : Set(activeMembers.map(\.id))
                            recomputeTotal()
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                } footer: {
                    if let hint { Text(hint) }
                }

                if splitMode == .equal {
                    guestsSection
                }

                if splitMode == .items {
                    itemsSections
                }

                payerSection

                Section("ملاحظة") {
                    TextField("اختياري", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(editing == nil ? "تسجيل وجبة" : "تعديل الوجبة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) { summaryBar }
            .sheet(item: $picking) { target in
                MenuPickerView(snapshot: snapshot,
                               title: pickerTitle(target),
                               quantities: quantities(for: target.memberId)) { item, delta in
                    add(item, delta: delta, for: target.memberId)
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        if !snapshot.mealTypes.isEmpty {
            Section {
                Picker("الوجبة", selection: $mealTypeId) {
                    ForEach(snapshot.mealTypes) { type in
                        Text(type.name).tag(Optional(type.id))
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mealTypeId) { _, _ in applySuggestion(keepAttendees: editing != nil) }
            }
        }

        Section {
            Picker("طريقة التقسيم", selection: $splitMode) {
                Text("بالتساوي").tag(MealRecord.SplitMode.equal)
                Text("كلٌّ حسب طلبه").tag(MealRecord.SplitMode.items)
            }
            .pickerStyle(.segmented)
            .onChange(of: splitMode) { _, mode in
                Haptics.tap()
                if mode == .items && lines.isEmpty { repeatLastOrder(silently: true) }
            }

            DatePicker("التاريخ", selection: $day, in: ...Date.now.addingTimeInterval(86_400),
                       displayedComponents: .date)

            if splitMode == .equal {
                HStack {
                    Text("المبلغ الكلي")
                    Spacer()
                    TextField("0", text: $totalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 140)
                    Text(MoneyFormatter.riyalSign)
                        .font(.custom("saudi_riyalregular", size: 18, relativeTo: .title3))
                }
            }
        }
    }

    private var guestsSection: some View {
        Section {
            ForEach(guests) { guest in
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus").foregroundStyle(.secondary)
                    Text(guest.name)
                    Spacer()
                    Text("على \(memberName(guest.hostId))").font(.caption).foregroundStyle(.secondary)
                }
                .opacity(attendees.contains(guest.hostId) ? 1 : 0.4)
                .swipeActions {
                    Button(role: .destructive) {
                        guests.removeAll { $0.id == guest.id }
                        recomputeTotal()
                    } label: { Label("حذف", systemImage: "trash") }
                }
            }
            Button {
                newGuestName = ""
                newGuestHost = orderedAttendees.first?.id
                addingGuest = true
            } label: {
                Label("إضافة ضيف", systemImage: "person.badge.plus")
            }
            .disabled(attendees.isEmpty)
        } header: {
            Text("ضيوف")
        } footer: {
            Text("الضيف يُحسب في التقسيم ونصيبه على العضو الذي دعاه، بدون أن يُضاف للأعضاء.")
        }
        .alert("ضيف لمرة واحدة", isPresented: $addingGuest) {
            TextField("اسم الضيف", text: $newGuestName)
            ForEach(orderedAttendees) { member in
                Button("على حساب \(member.name)") { addGuest(host: member.id) }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("اكتب اسم الضيف ثم اختر من يدفع عنه")
        }
    }

    private var payerSection: some View {
        Section {
            Picker("من دفع للمطعم؟", selection: $payerId) {
                Text("لم يدفع أحد من الأعضاء").tag(String?.none)
                ForEach(activeMembers) { member in
                    Text(member.name).tag(Optional(member.id))
                }
            }
        } footer: {
            if let payerId, total.isPositive {
                Text("سيُسجَّل لـ \(memberName(payerId)) سداد بقيمة \(MoneyFormatter.plain(total)) مرتبط بهذه الوجبة.")
            } else {
                Text("إذا دفع أحد الأعضاء الحساب من جيبه يُحسب له كسداد تلقائياً.")
            }
        }
    }

    private func memberName(_ id: String) -> String {
        snapshot.members.first { $0.id == id }?.name ?? "عضو"
    }

    private func addGuest(host: String) {
        let name = newGuestName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Haptics.tap()
        guests.append(Guest(name: name, hostId: host))
        recomputeTotal()
    }

    @ViewBuilder
    private var itemsSections: some View {
        Section {
            ForEach(lines.filter { $0.memberId == nil }) { line in
                LineRow(line: line, onChange: changeQuantity)
            }
            Button {
                picking = .shared
            } label: {
                Label("إضافة صنف مشترك", systemImage: "plus")
            }
        } header: {
            Text("أصناف مشتركة")
        } footer: {
            Text("تُقسَّم بالتساوي على كل الحاضرين، مثل صحن في الوسط أو إبريق شاي.")
        }

        Section {
            HStack {
                Text("توصيل / ضريبة / خصم")
                Spacer()
                TextField("0", text: $extrasText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(maxWidth: 110)
            }
            HStack {
                Text("مجموع الأصناف")
                Spacer()
                MoneyText(money: itemSplit.itemsTotal).foregroundStyle(.secondary)
            }
        } footer: {
            Text("يُوزَّع التوصيل حسب قيمة طلب كل شخص. اكتب الخصم بالسالب مثل ‎-5")
        }

        Section {
            Button {
                repeatLastOrder(silently: false)
            } label: {
                Label("نفس طلب آخر مرة", systemImage: "arrow.counterclockwise")
            }
            .disabled(snapshot.lastItemizedMeal(mealTypeId: mealTypeId) == nil)

            Button {
                UIPasteboard.general.string = restaurantOrderMessage
                Haptics.success()
                copiedOrder = true
            } label: {
                Label(copiedOrder ? "تم نسخ الطلب ✓" : "نسخ الطلب للمطعم", systemImage: "doc.on.doc")
            }
            .disabled(lines.isEmpty)

            if !lines.isEmpty {
                ShareLink(item: restaurantOrderMessage) {
                    Label("إرسال الطلب للمطعم", systemImage: "paperplane")
                }
            }
        }
    }

    private var summaryBar: some View {
        HStack {
            if attendees.isEmpty {
                Text("اختر الحاضرين").foregroundStyle(.secondary)
            } else if total.isPositive {
                if splitMode == .equal {
                    Text("نصيب الشخص")
                    Spacer()
                    MoneyText(money: SplitCalculator.perPerson(total, attendeeCount: peopleCount),
                              font: .title3, weight: .bold)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: peopleCount)
                } else {
                    Text("الإجمالي")
                    Spacer()
                    MoneyText(money: total, font: .title3, weight: .bold)
                }
            } else {
                Text(splitMode == .equal ? "أدخل المبلغ الكلي" : "أضف طلبات الحاضرين")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var canSave: Bool { !saving && !attendees.isEmpty && total.isPositive }

    /// Guests whose host is still ticked.
    private var activeGuests: [Guest] {
        guests.filter { attendees.contains($0.hostId) }
    }

    private var peopleCount: Int { attendees.count + activeGuests.count }

    private var totalEditedByHand: Bool { totalText != autoTotalText }

    private var restaurantOrderMessage: String {
        let attendeeIds = Set(attendees)
        let relevant = lines.filter { $0.memberId == nil || attendeeIds.contains($0.memberId!) }
        return "طلب \(selectedType?.name ?? "اليوم"):\n" + ItemSplitCalculator.restaurantOrderText(relevant)
    }

    // MARK: - Shares & lines

    private func share(for member: Member) -> Money? {
        guard attendees.contains(member.id), total.isPositive else { return nil }
        switch splitMode {
        case .equal:
            let shares = SplitCalculator.splitWithGuests(total, attendeeIds: orderedAttendees.map(\.id),
                                                         guests: activeGuests)
            return shares.filter { $0.memberId == member.id }.map(\.share).sum()
        case .items:
            return itemSplit.shares.first { $0.id == member.id }?.share
        }
    }

    private func lines(for memberId: String?) -> [OrderLine] {
        lines.filter { $0.memberId == memberId }
    }

    private func quantities(for memberId: String?) -> [String: Int] {
        Dictionary(lines(for: memberId).map { ($0.itemName, $0.quantity) }, uniquingKeysWith: +)
    }

    private func pickerTitle(_ target: PickTarget) -> String {
        guard let id = target.memberId else { return "أصناف مشتركة" }
        return "طلب " + (snapshot.members.first { $0.id == id }?.name ?? "")
    }

    private func add(_ item: MenuItem, delta: Int, for memberId: String?) {
        Haptics.tap()
        if let index = lines.firstIndex(where: { $0.memberId == memberId && $0.itemName == item.name }) {
            lines[index].quantity += delta
            if lines[index].quantity <= 0 { lines.remove(at: index) }
        } else if delta > 0 {
            lines.append(OrderLine(recordId: editing?.id ?? "", memberId: memberId, itemName: item.name,
                                   unitPrice: item.price, quantity: delta))
        }
        copiedOrder = false
    }

    private func changeQuantity(_ lineId: String, _ delta: Int) {
        guard let index = lines.firstIndex(where: { $0.id == lineId }) else { return }
        Haptics.tap()
        lines[index].quantity += delta
        if lines[index].quantity <= 0 { lines.remove(at: index) }
        copiedOrder = false
    }

    /// Copies the latest itemized order of this meal type, keeping only
    /// current attendees (and shared items).
    private func repeatLastOrder(silently: Bool) {
        guard let last = snapshot.lastItemizedMeal(mealTypeId: mealTypeId) else { return }
        let previous = snapshot.orderLines(of: last)
        let previousAttendees = Set(previous.compactMap(\.memberId))
        if attendees.isEmpty || !silently {
            attendees.formUnion(previousAttendees.intersection(Set(activeMembers.map(\.id))))
        }
        lines = previous
            .filter { $0.memberId == nil || attendees.contains($0.memberId!) }
            .map { OrderLine(recordId: editing?.id ?? "", memberId: $0.memberId, itemName: $0.itemName,
                             unitPrice: $0.unitPrice, quantity: $0.quantity) }
        extrasText = AmountParser.text(from: last.extras)
        if !silently {
            Haptics.success()
            hint = "نُسخ طلب آخر \(selectedType?.name ?? "وجبة") (\(last.day))"
        }
    }

    // MARK: - Equal-split helpers

    private func setAutoTotal(_ money: Money) {
        let text = AmountParser.text(from: money)
        totalText = text
        autoTotalText = text
    }

    private func toggle(_ member: Member) {
        Haptics.tap()
        if attendees.contains(member.id) {
            attendees.remove(member.id)
        } else {
            attendees.insert(member.id)
        }
        recomputeTotal()
    }

    /// Keeps total = usual price × attendees until the user types a total.
    private func recomputeTotal() {
        guard splitMode == .equal, !totalEditedByHand,
              let price = selectedType?.defaultPrice, price.isPositive else { return }
        setAutoTotal(price * peopleCount)
    }

    // MARK: - Loading & saving

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        if let editing {
            mealTypeId = editing.mealTypeId
            day = editing.day.date()
            attendees = Set(snapshot.participants(of: editing).compactMap(\.memberId))
            splitMode = editing.splitMode
            totalText = AmountParser.text(from: editing.totalAmount)
            autoTotalText = "\u{0}" // treat the saved total as typed by hand
            lines = snapshot.orderLines(of: editing)
            guests = snapshot.guests(of: editing)
            payerId = snapshot.billPayment(of: editing)?.memberId
            extrasText = AmountParser.text(from: editing.extras)
            note = editing.note
            return
        }

        mealTypeId = QuickLogPlanner.likelyMealType(snapshot.mealTypes)?.id
        applySuggestion(keepAttendees: false)
    }

    private func applySuggestion(keepAttendees: Bool) {
        let suggestion = AttendanceSuggester.suggest(mealType: selectedType, members: snapshot.members,
                                                     records: snapshot.records, participants: snapshot.participants)
        if !keepAttendees {
            attendees = Set(suggestion.attendeeIds)
        }
        switch suggestion.reason {
        case .sameAsLastTime(let day):
            hint = "حُدّد نفس حضور آخر \(selectedType?.name ?? "وجبة") (\(day))"
        case .defaultAttendees:
            hint = "حُدّد الأعضاء الذين يحضرون عادة"
        }

        guard editing == nil else { return }
        // If this meal type was itemized last time, start itemized with the same order.
        let lastOfType = snapshot.records
            .filter { $0.mealTypeId == mealTypeId }
            .max { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }
        if lastOfType?.splitMode == .items {
            splitMode = .items
            repeatLastOrder(silently: true)
        } else {
            splitMode = .equal
            lines = []
            if let suggested = suggestion.total, !keepAttendees, !totalEditedByHand {
                setAutoTotal(suggested)
            }
        }
    }

    private func save() {
        guard canSave else { return }
        saving = true
        let record = MealRecord(
            id: editing?.id ?? UUID().uuidString.lowercased(),
            listId: snapshot.list.id,
            mealTypeId: mealTypeId,
            mealName: selectedType?.name ?? editing?.mealName ?? "وجبة",
            day: Day(day),
            totalAmount: total,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: editing?.createdAt ?? .now
        )
        let people = orderedAttendees
        let mode = splitMode
        let currentLines = lines
        let currentExtras = extras
        let currentGuests = activeGuests
        let payer = snapshot.members.first { $0.id == payerId }
        Task {
            do {
                if mode == .items {
                    try await store.saveItemizedMeal(record, attendees: people, lines: currentLines,
                                                     extras: currentExtras, payer: payer)
                } else {
                    try await store.saveMeal(record, attendees: people, guests: currentGuests, payer: payer)
                }
                Haptics.success()
                toaster.show(editing == nil ? "سُجّلت \(record.mealName) ✓" : "حُفظت التعديلات")
                dismiss()
            } catch {
                saving = false
            }
        }
    }
}

// MARK: - Rows

private struct AttendeeRow: View {
    let member: Member
    let isOn: Bool
    let share: Money?
    let lines: [OrderLine]
    let showsItems: Bool
    let onToggle: () -> Void
    let onAddItem: () -> Void
    let onChangeQuantity: (String, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOn ? Color.qattahAccent : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: isOn)
                    Text(member.emoji)
                    Text(member.name).foregroundStyle(.primary)
                    Spacer()
                    if let share {
                        MoneyText(money: share, font: .subheadline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: share.riyals))
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .contentShape(Rectangle())
                .animation(.snappy, value: share)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])

            if showsItems {
                ForEach(lines) { line in
                    LineRow(line: line, onChange: onChangeQuantity)
                        .padding(.leading, 36)
                }
                Button(action: onAddItem) {
                    Label(lines.isEmpty ? "أضف طلبه" : "صنف آخر", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .padding(.leading, 36)
            }
        }
    }
}

private struct LineRow: View {
    let line: OrderLine
    let onChange: (String, Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(line.itemName).font(.subheadline)
            Text("× \(line.quantity)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            MoneyText(money: line.lineTotal, font: .subheadline).foregroundStyle(.secondary)
            Stepper("", onIncrement: { onChange(line.id, 1) }, onDecrement: { onChange(line.id, -1) })
                .labelsHidden()
                .fixedSize()
        }
    }
}

// MARK: - Menu picker

/// The list's restaurant menu: tap to add, with a quick "new item" row.
struct MenuPickerView: View {
    let snapshot: ListSnapshot
    let title: String
    let quantities: [String: Int]
    let onChange: (MenuItem, Int) -> Void

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var newPrice = ""
    @State private var localQuantities: [String: Int] = [:]
    @State private var addedItems: [MenuItem] = []
    @FocusState private var nameFocused: Bool

    private var items: [MenuItem] {
        snapshot.menuItems + addedItems.filter { added in !snapshot.menuItems.contains { $0.id == added.id } }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("صنف جديد", text: $newName).focused($nameFocused)
                        TextField("السعر", text: $newPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 80)
                        Button("إضافة", action: addNewItem)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty
                                      || AmountParser.money(from: newPrice) == nil)
                    }
                } footer: {
                    Text("يُحفظ الصنف في قائمة المطعم لهذه القائمة.")
                }

                Section("قائمة المطعم") {
                    if items.isEmpty {
                        Text("أضف أصناف المطعم مرة واحدة وتبقى محفوظة")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                MoneyText(money: item.price, font: .caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            let quantity = localQuantities[item.name] ?? 0
                            if quantity > 0 {
                                Button { change(item, -1) } label: { Image(systemName: "minus.circle") }
                                    .buttonStyle(.borderless)
                                Text("\(quantity)").monospacedDigit().frame(minWidth: 20)
                            }
                            Button { change(item, 1) } label: {
                                Image(systemName: "plus.circle.fill").font(.title3)
                            }
                            .buttonStyle(.borderless)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { try? await store.deleteMenuItem(id: item.id) }
                                addedItems.removeAll { $0.id == item.id }
                            } label: {
                                Label("حذف من القائمة", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
            .onAppear {
                localQuantities = quantities
                if snapshot.menuItems.isEmpty { nameFocused = true }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func change(_ item: MenuItem, _ delta: Int) {
        localQuantities[item.name] = max(0, (localQuantities[item.name] ?? 0) + delta)
        onChange(item, delta)
    }

    private func addNewItem() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let price = AmountParser.money(from: newPrice) else { return }
        let item = snapshot.menuItems.first { $0.name == name }
            ?? MenuItem(listId: snapshot.list.id, name: name, price: price)
        if !snapshot.menuItems.contains(where: { $0.id == item.id }) {
            addedItems.append(item)
            Task { try? await store.saveMenuItem(item) }
        }
        change(item, 1)
        newName = ""
        newPrice = ""
        nameFocused = true
    }
}
