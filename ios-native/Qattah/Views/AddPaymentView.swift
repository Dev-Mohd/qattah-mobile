import SwiftUI
import QattahKit

/// Record (or edit) a member's payment. New payments default to the full balance.
struct AddPaymentView: View {
    let member: Member
    let balance: MemberBalance?
    var existing: Payment?

    @Environment(\.store) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster
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
                            let after = balance.net + (existing?.amount ?? .zero) - amount
                            MoneyText(money: after.magnitude, weight: .semibold)
                                .foregroundStyle(after.isPositive ? Color.owes : after.isNegative ? Color.credit : .secondary)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "سداد \(member.name)" : "تعديل سداد \(member.name)")
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
                if let existing {
                    amountText = AmountParser.text(from: existing.amount)
                    paidOn = existing.paidOn.date()
                    note = existing.note
                } else if let owed = balance?.net, owed.isPositive, amountText.isEmpty {
                    amountText = AmountParser.text(from: owed)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        saving = true
        var payment = existing ?? Payment(listId: member.listId, memberId: member.id, memberName: member.name,
                                          amount: amount, paidOn: Day(paidOn))
        payment.amount = amount
        payment.note = note.trimmingCharacters(in: .whitespaces)
        payment.paidOn = Day(paidOn)
        Task {
            do {
                try await store.savePayment(payment)
                Haptics.success()
                toaster.show("سُجّل سداد \(member.name) \(MoneyFormatter.plain(amount))", symbol: "banknote.fill")
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
