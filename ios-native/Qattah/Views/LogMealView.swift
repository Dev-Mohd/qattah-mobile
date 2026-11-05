import SwiftUI
import QattahKit

/// Log (or edit) a meal. Designed so a normal day is: open → tap «حفظ».
/// - Remembers who attended this meal type last time.
/// - Fills the total from the meal type's usual price × attendees.
/// - Shows each person's exact share before saving.
struct LogMealView: View {
    let snapshot: ListSnapshot
    var editing: MealRecord?

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mealTypeId: String?
    @State private var day = Date.now
    @State private var attendees: Set<String> = []
    @State private var totalText = ""
    /// The last total the app filled in by itself. If the field differs, the user typed it.
    @State private var autoTotalText = ""
    @State private var note = ""
    @State private var hint: String?
    @State private var saving = false
    @State private var didLoad = false

    private var activeMembers: [Member] {
        snapshot.members.filter { $0.isActive || attendees.contains($0.id) }
    }

    private var selectedType: MealType? {
        snapshot.mealTypes.first { $0.id == mealTypeId }
    }

    private var total: Money { AmountParser.money(from: totalText) ?? .zero }

    private var orderedAttendees: [Member] {
        activeMembers.filter { attendees.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    DatePicker("التاريخ", selection: $day, in: ...Date.now.addingTimeInterval(86_400),
                               displayedComponents: .date)
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

                Section {
                    ForEach(activeMembers) { member in
                        AttendeeRow(member: member,
                                    isOn: attendees.contains(member.id),
                                    share: share(for: member)) {
                            toggle(member)
                        }
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
            .onAppear(perform: load)
        }
    }

    private var summaryBar: some View {
        HStack {
            if attendees.isEmpty {
                Text("اختر الحاضرين").foregroundStyle(.secondary)
            } else if total.isPositive {
                Text("نصيب الشخص")
                Spacer()
                MoneyText(money: SplitCalculator.perPerson(total, attendeeCount: attendees.count),
                          font: .title3, weight: .bold)
            } else {
                Text("أدخل المبلغ الكلي").foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var canSave: Bool { !saving && !attendees.isEmpty && total.isPositive }

    private var totalEditedByHand: Bool { totalText != autoTotalText }

    private func setAutoTotal(_ money: Money) {
        let text = AmountParser.text(from: money)
        totalText = text
        autoTotalText = text
    }

    // MARK: - Logic

    private func share(for member: Member) -> Money? {
        guard attendees.contains(member.id), total.isPositive else { return nil }
        let shares = SplitCalculator.split(total, among: orderedAttendees.map(\.id))
        return shares.first { $0.id == member.id }?.share
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
        guard !totalEditedByHand, let price = selectedType?.defaultPrice, price.isPositive else { return }
        setAutoTotal(price * attendees.count)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        if let editing {
            mealTypeId = editing.mealTypeId
            day = editing.day.date()
            attendees = Set(snapshot.participants(of: editing).compactMap(\.memberId))
            totalText = AmountParser.text(from: editing.totalAmount)
            autoTotalText = "\u{0}" // treat the saved total as typed by hand
            note = editing.note
            return
        }

        mealTypeId = mostLikelyMealType()?.id
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
        if let suggested = suggestion.total, !keepAttendees, !totalEditedByHand {
            setAutoTotal(suggested)
        }
    }

    /// Before 11:00 → the first meal type (usually breakfast); after → the second, if any.
    private func mostLikelyMealType() -> MealType? {
        let types = snapshot.mealTypes
        guard !types.isEmpty else { return nil }
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 11, types.count > 1 { return types[1] }
        return types[0]
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
        Task {
            do {
                try await store.saveMeal(record, attendees: people)
                Haptics.success()
                dismiss()
            } catch {
                saving = false
            }
        }
    }
}

private struct AttendeeRow: View {
    let member: Member
    let isOn: Bool
    let share: Money?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.qattahAccent : .secondary)
                Text(member.emoji)
                Text(member.name).foregroundStyle(.primary)
                Spacer()
                if let share {
                    MoneyText(money: share, font: .subheadline).foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
