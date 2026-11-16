import SwiftUI
import QattahKit

/// "Who pays whom": the fewest transfers that bring every balance to zero.
struct SettlementView: View {
    let snapshot: ListSnapshot

    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(Toaster.self) private var toaster
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var organizerId: String?
    @State private var done: Set<String> = []
    @State private var appeared = false

    private var plan: [Transfer] {
        SettlementPlanner.plan(balances: snapshot.balances, organizerId: organizerId)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("منظّم القطة", selection: $organizerId) {
                        Text("شخص من خارج القائمة").tag(String?.none)
                        ForEach(snapshot.members.filter(\.isActive)) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    .onChange(of: organizerId) { _, value in
                        var list = snapshot.list
                        list.organizerId = value
                        Task { try? await store.saveList(list) }
                    }
                } footer: {
                    Text("المنظّم هو من يدفع للمطعم عادة ويستلم المبالغ. الوجبات التي لم يُسجَّل من دفعها تُحسب له.")
                }

                if plan.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 54))
                                .foregroundStyle(Color.credit)
                                .symbolEffect(.bounce, value: appeared)
                            Text("كل الحسابات مصفّاة").font(.headline)
                            Text("لا توجد تحويلات مطلوبة").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                } else {
                    Section {
                        ForEach(Array(plan.enumerated()), id: \.element.id) { index, transfer in
                            TransferRow(transfer: transfer, isDone: done.contains(transfer.id),
                                        canMessage: phone(of: transfer.fromId) != nil,
                                        onMessage: { message(transfer) },
                                        onRecord: { record(transfer) })
                                .opacity(appeared ? 1 : 0)
                                .offset(x: appeared ? 0 : 30)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.07),
                                           value: appeared)
                        }
                    } header: {
                        Text("\(plan.count) تحويل يصفّي كل الحسابات")
                    } footer: {
                        Text("«تم التحويل» يسجّل السداد للطرفين تلقائياً. ابدأ بالتحويلات الأكبر.")
                    }
                }
            }
            .navigationTitle("خطة التسوية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
                if !plan.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareText) {
                            Label("مشاركة الخطة", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                organizerId = snapshot.list.organizerId
                withAnimation { appeared = true }
            }
        }
    }

    private var shareText: String {
        var lines = ["🤝 تسوية قطّة \(snapshot.list.name)", ""]
        lines += plan.map { "• \($0.fromName) ← يحوّل \(MoneyFormatter.plain($0.amount)) إلى \($0.toName)" }
        if !settings.paymentDetails.isEmpty, plan.contains(where: { $0.toId == nil || $0.toId == organizerId }) {
            lines.append("")
            lines.append(contentsOf: settings.paymentDetails.messageLines)
        }
        lines.append("")
        lines.append("— أُرسلت من تطبيق قطّه")
        return lines.joined(separator: "\n")
    }

    private func phone(of memberId: String) -> String? {
        snapshot.members.first { $0.id == memberId }?.phone
    }

    private func message(_ transfer: Transfer) {
        // Payment details are the organizer's own (from settings).
        let payment = (transfer.toId == nil || transfer.toId == organizerId) ? settings.paymentDetails : nil
        var adjusted = transfer
        if transfer.toId == organizerId, organizerId != nil {
            adjusted = Transfer(fromId: transfer.fromId, fromName: transfer.fromName, toId: nil,
                                toName: transfer.toName, amount: transfer.amount)
        }
        let text = SettlementPlanner.message(for: adjusted, listName: snapshot.list.name, payment: payment)
        if let url = WhatsApp.url(phone: phone(of: transfer.fromId), text: text) {
            openURL(url)
        }
    }

    private func record(_ transfer: Transfer) {
        let payments = SettlementPlanner.payments(for: transfer, listId: snapshot.list.id,
                                                  organizerId: organizerId, on: .today())
        Task {
            try? await store.savePayments(payments)
            Haptics.success()
            withAnimation(.spring) { _ = done.insert(transfer.id) }
            toaster.show("سُجّل تحويل \(transfer.fromName) ✓", symbol: "arrow.left.arrow.right.circle.fill")
        }
    }
}

private struct TransferRow: View {
    let transfer: Transfer
    let isDone: Bool
    let canMessage: Bool
    let onMessage: () -> Void
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Avatar(name: transfer.fromName, color: .owes)
                VStack(spacing: 2) {
                    MoneyText(money: transfer.amount, font: .headline, weight: .bold)
                    Image(systemName: "arrow.left")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Avatar(name: transfer.toName, color: .credit)
            }

            HStack {
                if canMessage {
                    Button(action: onMessage) {
                        Label("واتساب", systemImage: "message.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
                Spacer()
                Button(action: onRecord) {
                    Label(isDone ? "سُجّل" : "تم التحويل", systemImage: isDone ? "checkmark.circle.fill" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderedProminent)
                .tint(isDone ? .secondary : .qattahAccent)
                .disabled(isDone)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 6)
        .opacity(isDone ? 0.55 : 1)
    }
}

private struct Avatar: View {
    let name: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(name.prefix(1)))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(color.gradient, in: Circle())
            Text(name).font(.caption).lineLimit(1)
        }
        .frame(width: 80)
    }
}
