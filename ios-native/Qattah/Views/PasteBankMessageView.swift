import SwiftUI
import UniformTypeIdentifiers
import QattahKit

/// Paste a bank / wallet "money received" SMS: the amount and the sender
/// are read from it, the matching member is suggested, one tap records it.
struct PasteBankMessageView: View {
    let snapshot: ListSnapshot

    @Environment(\.store) private var store
    @Environment(Toaster.self) private var toaster
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var memberId: String?
    @State private var amountText = ""
    @State private var paidOn = Date.now
    @State private var parsed: ParsedBankMessage?

    private var members: [Member] { snapshot.members.filter(\.isActive) }
    private var amount: Money { AmountParser.money(from: amountText) ?? .zero }
    private var member: Member? { snapshot.members.first { $0.id == memberId } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // PasteButton reads the clipboard without iOS's "allow paste" prompt.
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first {
                            Task { @MainActor in apply(first) }
                        }
                    }
                    .buttonBorderShape(.capsule)
                    .labelStyle(.titleAndIcon)

                    TextField("أو الصق رسالة التحويل هنا", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: text) { _, value in apply(value, updateText: false) }
                } header: {
                    Text("رسالة البنك أو المحفظة")
                } footer: {
                    Text("انسخ رسالة «حوالة واردة» من تطبيق الرسائل ثم الصقها. لا يحفظ التطبيق نص الرسالة.")
                }

                if parsed != nil {
                    Section("ما فهمه التطبيق") {
                        if let sender = parsed?.senderName {
                            LabeledContent("المحوّل", value: sender)
                        }
                        if parsed?.isIncoming == false {
                            Label("يبدو أن الرسالة ليست حوالة واردة. تأكد قبل الحفظ.", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Picker("العضو", selection: $memberId) {
                            Text("اختر العضو").tag(String?.none)
                            ForEach(members) { member in
                                Text(member.name).tag(Optional(member.id))
                            }
                        }

                        HStack {
                            Text("المبلغ")
                            Spacer()
                            TextField("0", text: $amountText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.title3.weight(.semibold).monospacedDigit())
                                .frame(maxWidth: 120)
                            Text(MoneyFormatter.riyalSign)
                                .font(.custom("saudi_riyalregular", size: 18, relativeTo: .title3))
                        }

                        DatePicker("التاريخ", selection: $paidOn, in: ...Date.now, displayedComponents: .date)
                    }

                    if let member, let balance = snapshot.balances.members.first(where: { $0.id == member.id }),
                       amount.isPositive {
                        Section {
                            HStack {
                                Text("رصيد \(member.name) بعد السداد")
                                Spacer()
                                let after = balance.net - amount
                                MoneyText(money: after.magnitude, weight: .semibold)
                                    .foregroundStyle(after.isPositive ? Color.owes : after.isNegative ? Color.credit : .secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("سداد من رسالة البنك")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ", action: save)
                        .fontWeight(.semibold)
                        .disabled(member == nil || !amount.isPositive)
                }
            }
        }
    }

    private func apply(_ message: String, updateText: Bool = true) {
        if updateText { text = message }
        let result = BankMessageParser.parse(message)
        withAnimation(.snappy) { parsed = result }
        if let value = result.amount { amountText = AmountParser.text(from: value) }
        if let sender = result.senderName, let match = BankMessageParser.bestMatch(sender: sender, members: members) {
            memberId = match.id
            Haptics.tap()
        }
    }

    private func save() {
        guard let member else { return }
        let payment = Payment(listId: snapshot.list.id, memberId: member.id, memberName: member.name,
                              amount: amount, note: "تحويل بنكي", paidOn: Day(paidOn))
        Task {
            try? await store.savePayment(payment)
            Haptics.success()
            toaster.show("سُجّل سداد \(member.name) \(MoneyFormatter.plain(amount))", symbol: "banknote.fill")
            dismiss()
        }
    }
}
