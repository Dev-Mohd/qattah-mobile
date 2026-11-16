import SwiftUI
import GRDB
import QattahKit

/// صندوق الشلة: how much the organizer is holding, how long it lasts, and
/// who needs to top up. A reading of the existing balances — nothing here
/// is stored separately.
struct PotView: View {
    let listId: String

    @Environment(\.store) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot: ListSnapshot?
    @State private var appeared = false
    @State private var contacted: Set<String> = []
    @State private var toppingUp = false

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot {
                    content(snapshot)
                } else {
                    ProgressView()
                }
            }
            .screenBackground(tint: Color(hex: snapshot?.list.color ?? "#10B981"))
            .navigationTitle("صندوق الشلة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } }
            }
        }
        .task {
            do {
                for try await value in store.observeList(id: listId) {
                    withAnimation(.snappy) { snapshot = value }
                }
            } catch {}
        }
    }

    private func content(_ snapshot: ListSnapshot) -> some View {
        @Bindable var settings = settings
        let pot = PotCalculator.summary(balances: snapshot.balances, records: snapshot.records,
                                        threshold: snapshot.list.potThreshold)
        // Scale of the per-member bars: the largest credit, or twice the threshold.
        let scale = max(pot.members.map(\.credit.halalas).max() ?? 0, pot.threshold.halalas * 2, 1)

        return List {
            Section {
                PotHeader(pot: pot)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                Stepper(value: Binding(
                    get: { pot.threshold.halalas / 100 },
                    set: { newValue in
                        Task { try? await store.setPotThreshold(Money(halalas: newValue * 100), listId: listId) }
                    }
                ), in: 0...1000, step: 10) {
                    HStack {
                        Text("حد التنبيه")
                        Spacer()
                        MoneyText(money: pot.threshold, weight: .semibold)
                    }
                }
                Picker("نبرة الرسائل", selection: $settings.messageTone) {
                    ForEach(MessageTone.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } footer: {
                Text("من ينزل رصيده عن الحد يظهر له «يحتاج تعبئة».")
            }

            Section {
                if pot.members.isEmpty {
                    Text("لا يوجد أعضاء بعد").foregroundStyle(.secondary)
                }
                ForEach(Array(pot.members.enumerated()), id: \.element.id) { index, row in
                    PotMemberRow(row: row, scale: scale, threshold: pot.threshold, appeared: appeared,
                                 contacted: contacted.contains(row.id),
                                 message: message(for: row, snapshot: snapshot),
                                 whatsAppURL: WhatsApp.url(phone: row.balance.member.phone,
                                                           text: message(for: row, snapshot: snapshot)),
                                 onContact: { url in
                                     contacted.insert(row.id)
                                     if let url { openURL(url) }
                                 })
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(Double(index) * 0.04),
                                   value: appeared)
                }
            } header: {
                HStack {
                    Text("الأعضاء")
                    Spacer()
                    if !pot.membersNeedingTopUp.isEmpty {
                        Text("\(pot.membersNeedingTopUp.count) يحتاجون تعبئة")
                            .foregroundStyle(.orange)
                            .textCase(nil)
                    }
                }
            } footer: {
                if settings.paymentDetails.isEmpty {
                    Text("أضف رقم الآيبان من الإعدادات ليظهر في رسائل التعبئة.")
                }
            }
        }
        .onAppear { appeared = true }
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.tap()
                toppingUp = true
            } label: {
                Label("تعبئة الشلة", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .primaryActionStyle()
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .disabled(pot.members.isEmpty)
        }
        .sheet(isPresented: $toppingUp) {
            TopUpView(snapshot: snapshot, preselected: Set(pot.membersNeedingTopUp.map(\.id)))
        }
    }

    /// Suggests the amount of the member's latest top-up, if they have one.
    private func message(for row: PotSummary.MemberRow, snapshot: ListSnapshot) -> String {
        let lastTopUp = snapshot.payments
            .first { $0.memberId == row.id && !$0.isBillPayment && $0.amount.isPositive }?.amount
        return ShareMessageBuilder.topUpMessage(listName: snapshot.list.name, row: row, suggested: lastTopUp,
                                                tone: settings.messageTone, payment: settings.paymentDetails)
    }
}

private struct PotHeader: View {
    let pot: PotSummary

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: pot.balance.isNegative ? "tray" : "tray.full.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 4) {
                Text(pot.balance.isNegative ? "المنظّم دافع من جيبه" : "في الصندوق الآن")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(MoneyFormatter.number(pot.balance.magnitude))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: pot.balance.riyals))
                    Text(MoneyFormatter.riyalSign)
                        .font(.custom("saudi_riyalregular", size: 24, relativeTo: .title))
                        .opacity(0.8)
                }
                .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                PotFact(title: "يكفي تقريباً", value: daysText)
                PotFact(title: "متوسط اليوم", value: MoneyFormatter.plain(pot.averageDailySpending))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(colors: pot.balance.isNegative
                           ? [Color(red: 0.55, green: 0.22, blue: 0.12), Color(red: 0.3, green: 0.1, blue: 0.06)]
                           : [Color(red: 0.02, green: 0.37, blue: 0.27), Color(red: 0.01, green: 0.18, blue: 0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var daysText: String {
        guard let days = pot.daysLeft else { return "—" }
        switch days {
        case 0: return "أقل من يوم"
        case 1: return "يوم واحد"
        case 2: return "يومين"
        case 3...10: return "\(days) أيام"
        default: return "\(days) يوماً"
        }
    }
}

private struct PotFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PotMemberRow: View {
    let row: PotSummary.MemberRow
    let scale: Int
    let threshold: Money
    let appeared: Bool
    let contacted: Bool
    let message: String
    let whatsAppURL: URL?
    let onContact: (URL?) -> Void

    private var color: Color {
        if row.credit.isNegative { return .owes }
        return row.needsTopUp ? .orange : .credit
    }

    private var fraction: CGFloat {
        guard appeared, row.credit.isPositive else { return 0 }
        return min(1, CGFloat(row.credit.halalas) / CGFloat(scale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(row.balance.member.emoji)
                Text(row.balance.member.name).font(.body.weight(.medium))
                if row.needsTopUp {
                    Text("يحتاج تعبئة")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
                Spacer()
                if row.credit.isNegative {
                    HStack(spacing: 4) {
                        Text("عليه").font(.caption)
                        MoneyText(money: row.credit.magnitude, weight: .semibold)
                    }
                    .foregroundStyle(Color.owes)
                } else {
                    MoneyText(money: row.credit, weight: .semibold).foregroundStyle(color)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color.gradient).frame(width: proxy.size.width * fraction)
                    // Threshold marker
                    Rectangle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 2)
                        .offset(x: proxy.size.width * min(1, CGFloat(threshold.halalas) / CGFloat(scale)))
                        .opacity(threshold.isPositive ? 1 : 0)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)

            if row.needsTopUp {
                HStack {
                    if let whatsAppURL {
                        Button {
                            onContact(whatsAppURL)
                        } label: {
                            Label("واتساب", systemImage: "message.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    }
                    ShareLink(item: message) {
                        Label("إرسال طلب تعبئة", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .simultaneousGesture(TapGesture().onEnded { onContact(nil) })
                    Spacer()
                    if contacted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.credit)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
