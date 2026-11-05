import SwiftUI
import QattahKit

/// Record that a member paid. Defaults to paying off the full balance.
struct AddPaymentView: View {
    let member: Member
    let balance: MemberBalance?

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var paidOn = Date.now
    @State private var note = ""
    @State private var saving = false

    private var amount: Money { AmountParser.money(from: amountText) ?? .zero }

    var body: some View {
        NavigationStack {
            Form {
                if let balance {
                    Section {
                        HStack {
                            Text(balance.status == .credit ? "له" : "المتبقي عليه")
                            Spacer()
                            MoneyText(money: balance.net.magnitude, weight: .semibold)
                                .foregroundStyle(balance.status.color)
                        }
                    }
                }

                Section("مبلغ السداد") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Text(MoneyFormatter.riyalSign)
                            .font(.custom("saudi_riyalregular", size: 20, relativeTo: .title2))
                    }
                    if let owed = balance?.net, owed.isPositive {
                        HStack {
                            QuickAmountButton(title: "كامل المبلغ") { amountText = AmountParser.text(from: owed) }
                            QuickAmountButton(title: "النصف") {
                                amountText = AmountParser.text(from: Money(halalas: owed.halalas / 2))
                            }
                        }
                    }
                }

                Section {
                    DatePicker("تاريخ السداد", selection: $paidOn, in: ...Date.now, displayedComponents: .date)
                    TextField("ملاحظة (اختياري)", text: $note)
                }

                if let balance, amount.isPositive {
                    Section {
                        HStack {
                            Text("الرصيد بعد السداد")
                            Spacer()
                            let after = balance.net - amount
                            MoneyText(money: after.magnitude, weight: .semibold)
                                .foregroundStyle(after.isPositive ? Color.owes : after.isNegative ? Color.credit : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("سداد \(member.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ", action: save)
                        .fontWeight(.semibold)
                        .disabled(saving || !amount.isPositive)
                }
            }
            .onAppear {
                if let owed = balance?.net, owed.isPositive, amountText.isEmpty {
                    amountText = AmountParser.text(from: owed)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        saving = true
        let payment = Payment(listId: member.listId, memberId: member.id, memberName: member.name,
                              amount: amount, note: note.trimmingCharacters(in: .whitespaces),
                              paidOn: Day(paidOn))
        Task {
            do {
                try await store.savePayment(payment)
                Haptics.success()
                dismiss()
            } catch {
                saving = false
            }
        }
    }
}

private struct QuickAmountButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}
