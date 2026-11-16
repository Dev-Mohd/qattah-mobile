import SwiftUI
import QattahKit

/// تعبئة الشلة: record the same top-up for several members in one go.
/// Amount first, tap who paid, save — the payments share a batch id so
/// they read as one event.
struct TopUpView: View {
    let snapshot: ListSnapshot
    /// Members ticked when the screen opens (those who need a top-up).
    var preselected: Set<String> = []

    @Environment(\.store) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var selected: Set<String> = []
    @State private var paidOn = Date.now
    @State private var saving = false
    @State private var didLoad = false
    @FocusState private var amountFocused: Bool

    private var members: [Member] { snapshot.members.filter(\.isActive) }
    private var amount: Money { AmountParser.money(from: amountText) ?? .zero }
    private var chosen: [Member] { members.filter { selected.contains($0.id) } }
    private var canSave: Bool { !saving && amount.isPositive && !chosen.isEmpty }
    private var note: String { "تعبئة \(Month(Day(paidOn)).arabicTitle)" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Text("المبلغ لكل عضو").font(.caption).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($amountFocused)
                                .fixedSize()
                                .frame(minWidth: 60)
                            Text(MoneyFormatter.riyalSign)
                                .font(.custom("saudi_riyalregular", size: 26, relativeTo: .largeTitle))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .monospacedDigit()

                        HStack(spacing: 8) {
                            ForEach([50, 100, 200], id: \.self) { value in
                                Button("\(value)") {
                                    Haptics.tap()
                                    amountText = "\(value)"
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(members) { member in
                            TopUpChip(member: member, isOn: selected.contains(member.id),
                                      credit: credit(of: member)) {
                                Haptics.tap()
                                if selected.contains(member.id) {
                                    selected.remove(member.id)
                                } else {
                                    selected.insert(member.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Text("من دفع؟ (\(selected.count) من \(members.count))")
                        Spacer()
                        Button(selected.count == members.count ? "إلغاء الكل" : "الكل") {
                            Haptics.tap()
                            selected = selected.count == members.count ? [] : Set(members.map(\.id))
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                } footer: {
                    Text("الرقم تحت الاسم هو رصيد العضو الحالي في الصندوق.")
                }

                Section {
                    DatePicker("تاريخ التعبئة", selection: $paidOn, in: ...Date.now, displayedComponents: .date)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("تعبئة الشلة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") { amountFocused = false }
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .onAppear(perform: load)
        }
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            HStack {
                if canSave {
                    Text("\(chosen.count) أعضاء × \(MoneyFormatter.plain(amount))")
                    Spacer()
                    MoneyText(money: amount * chosen.count, font: .headline, weight: .bold)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: chosen.count)
                } else {
                    Text(amount.isPositive ? "اختر من دفع" : "أدخل مبلغ التعبئة").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            Button(action: save) {
                Text("تسجيل التعبئة")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .primaryActionStyle()
            .controlSize(.large)
            .disabled(!canSave)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func credit(of member: Member) -> Money {
        -(snapshot.balances.members.first { $0.id == member.id }?.net ?? .zero)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        selected = preselected.intersection(Set(members.map(\.id)))
        if let last = PotCalculator.lastTopUpAmount(snapshot.payments) {
            amountText = AmountParser.text(from: last)
        } else {
            amountFocused = true
        }
    }

    private func save() {
        guard canSave else { return }
        saving = true
        let payments = PotCalculator.topUpPayments(listId: snapshot.list.id, members: chosen, amount: amount,
                                                   on: Day(paidOn), note: note)
        let count = chosen.count
        Task {
            do {
                try await store.savePayments(payments)
                Haptics.success()
                toaster.show("سُجّلت تعبئة \(count) أعضاء ✓", symbol: "tray.and.arrow.down.fill")
                dismiss()
            } catch {
                saving = false
            }
        }
    }
}

private struct TopUpChip: View {
    let member: Member
    let isOn: Bool
    let credit: Money
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(member.emoji).font(.title2)
                Text(member.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(MoneyFormatter.number(credit))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(credit.isNegative ? Color.owes : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? Color.qattahAccent.opacity(0.14) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isOn ? Color.qattahAccent : .clear, lineWidth: 1.5)
            }
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.qattahAccent)
                        .padding(5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        .accessibilityLabel(member.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
