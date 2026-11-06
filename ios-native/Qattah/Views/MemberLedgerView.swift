import SwiftUI
import Charts
import QattahKit

/// Everything about one member: balance, payments (edit / delete with undo)
/// and the meals they attended.
struct MemberLedgerView: View {
    let listId: String
    let memberId: String

    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: ListSnapshot?
    @State private var addingPayment = false
    @State private var editingPayment: Payment?
    @State private var lastDeleted: Payment?
    @State private var statementURL: URL?

    private var member: Member? { snapshot?.members.first { $0.id == memberId } }
    private var balance: MemberBalance? { snapshot?.balances.members.first { $0.id == memberId } }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot, let member, let balance {
                    content(snapshot, member: member, balance: balance)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(member.map { "\($0.emoji) \($0.name)" } ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
        }
        .task {
            do {
                for try await value in store.observeList(id: listId) { snapshot = value }
            } catch {}
        }
    }

    private func content(_ snapshot: ListSnapshot, member: Member, balance: MemberBalance) -> some View {
        let reminder = ShareMessageBuilder.reminderMessage(listName: snapshot.list.name, balance: balance,
                                                           payment: settings.paymentDetails)
        let payments = snapshot.payments(of: member)
        let meals = snapshot.meals(attendedBy: member)

        return List {
            Section {
                VStack(spacing: 6) {
                    Text(balance.status == .credit ? "له" : balance.status == .owes ? "عليه" : "الحساب")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if balance.status == .settled {
                        Label("مسدّد بالكامل", systemImage: "checkmark.seal.fill")
                            .font(.title2.bold())
                            .foregroundStyle(Color.credit)
                    } else {
                        MoneyText(money: balance.net.magnitude, font: .largeTitle, weight: .bold)
                            .foregroundStyle(balance.status.color)
                    }
                    HStack(spacing: 16) {
                        if !balance.openingBalance.isZero {
                            figure("سابق", balance.openingBalance)
                        }
                        figure("الوجبات", balance.spent)
                        figure("السداد", balance.paid)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Button {
                    addingPayment = true
                } label: {
                    Label("تسجيل سداد", systemImage: "banknote")
                }
                Button {
                    statementURL = try? MemberStatementRenderer.render(snapshot: snapshot, member: member,
                                                                       balance: balance,
                                                                       payment: settings.paymentDetails)
                } label: {
                    Label("إرسال كشف حساب PDF", systemImage: "doc.richtext")
                }
                if balance.status == .owes {
                    if let url = WhatsApp.url(phone: member.phone, text: reminder) {
                        Button { openURL(url) } label: {
                            Label("تذكير بالواتساب", systemImage: "message")
                        }
                    }
                    ShareLink(item: reminder) {
                        Label("إرسال تذكير", systemImage: "bell")
                    }
                }
            }

            if meals.count > 1 {
                Section("مصروفه في آخر 6 أشهر") {
                    MemberMonthsChart(meals: meals)
                        .frame(height: 150)
                        .padding(.vertical, 6)
                }
            }

            Section("السدادات (\(payments.count))") {
                if payments.isEmpty {
                    Text("لا توجد سدادات").foregroundStyle(.secondary)
                }
                ForEach(payments) { payment in
                    PaymentRow(payment: payment)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !payment.isBillPayment { editingPayment = payment }
                        }
                        .swipeActions {
                            if !payment.isBillPayment {
                                Button(role: .destructive) { delete(payment) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                        }
                }
            }

            Section("الوجبات (\(meals.count))") {
                if meals.isEmpty {
                    Text("لم يحضر أي وجبة").foregroundStyle(.secondary)
                }
                ForEach(meals.prefix(60), id: \.record.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.record.mealName)
                            Text(item.record.day.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        MoneyText(money: item.share, font: .subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(item: Binding(get: { statementURL.map(ShareItem.init) }, set: { statementURL = $0?.url })) { item in
            ShareSheet(items: [item.url, reminder])
        }
        .sheet(isPresented: $addingPayment) {
            AddPaymentView(member: member, balance: balance)
        }
        .sheet(item: $editingPayment) { payment in
            AddPaymentView(member: member, balance: balance, existing: payment)
        }
        .overlay(alignment: .bottom) {
            if let deleted = lastDeleted {
                UndoBanner(text: "حُذف سداد \(MoneyFormatter.plain(deleted.amount))") { undo() }
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: lastDeleted?.id)
    }

    private func figure(_ title: String, _ money: Money) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            MoneyText(money: money, font: .subheadline, weight: .semibold)
        }
    }

    private func delete(_ payment: Payment) {
        Task {
            try? await store.deletePayment(id: payment.id)
            lastDeleted = payment
            try? await Task.sleep(for: .seconds(5))
            if lastDeleted?.id == payment.id { lastDeleted = nil }
        }
    }

    private func undo() {
        guard let payment = lastDeleted else { return }
        lastDeleted = nil
        Task { try? await store.savePayment(payment) }
    }
}

private struct PaymentRow: View {
    let payment: Payment

    var body: some View {
        HStack {
            Image(systemName: payment.isBillPayment ? "fork.knife.circle" : "banknote")
                .foregroundStyle(Color.credit)
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.paidOn.description)
                if !payment.note.isEmpty {
                    Text(payment.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if payment.isBillPayment {
                    Text("يُعدَّل من الوجبة نفسها").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            MoneyText(money: payment.amount, weight: .semibold).foregroundStyle(Color.credit)
        }
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct MemberMonthsChart: View {
    let meals: [(record: MealRecord, share: Money)]
    @State private var appeared = false

    private var months: [(month: Month, total: Money)] {
        var list = [Month.current()]
        while list.count < 6 { list.insert(list[0].previous, at: 0) }
        return list.map { month in
            (month: month, total: meals.filter { month.contains($0.record.day) }.map(\.share).sum())
        }
    }

    var body: some View {
        Chart(months, id: \.month) { item in
            BarMark(x: .value("الشهر", item.month.arabicTitle.components(separatedBy: " ").first ?? ""),
                    y: .value("المبلغ", appeared ? item.total.riyals : 0))
                .foregroundStyle(item.month == Month.current() ? Color.qattahAccent.gradient
                                                                : Color.qattahAccent.opacity(0.45).gradient)
                .cornerRadius(6)
        }
        .chartYAxis(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { appeared = true }
        }
    }
}
