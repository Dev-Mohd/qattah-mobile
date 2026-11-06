import SwiftUI
import Charts
import QattahKit

/// Monthly report: summary, daily chart, per-member table, PDF / text export.
struct ReportView: View {
    let snapshot: ListSnapshot

    @State private var month = Month.current()
    @State private var pdfURL: URL?
    @State private var pdfError: String?

    private var report: MonthlyReport {
        MonthlyReportBuilder.build(month: month, members: snapshot.members, records: snapshot.records,
                                   participants: snapshot.participants, payments: snapshot.payments)
    }

    private var months: [Month] {
        MonthlyReportBuilder.activeMonths(records: snapshot.records, payments: snapshot.payments)
    }

    var body: some View {
        let report = report

        List {
            Section {
                monthSwitcher
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "مصاريف الشهر", value: report.totalSpent, color: .primary)
                    StatTile(title: "السداد", value: report.totalPaid, color: .credit)
                    StatTile(title: "المتبقي المطلوب", value: report.closingOwed, color: .owes)
                    StatTile(title: "متوسط الوجبة", value: report.averageMeal, color: .primary,
                             caption: "\(report.mealCount) وجبة · \(report.paymentCount) سداد")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if !report.dailySpending.isEmpty {
                Section("المصروف اليومي") {
                    Chart(report.dailySpending, id: \.day) { item in
                        BarMark(x: .value("اليوم", item.day.day),
                                y: .value("المبلغ", item.amount.riyals))
                            .foregroundStyle(Color.qattahAccent.gradient)
                            .cornerRadius(4)
                    }
                    .chartXScale(domain: 1...31)
                    .chartXAxis {
                        AxisMarks(values: [1, 5, 10, 15, 20, 25, 31])
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                    .accessibilityLabel("رسم بياني للمصروف اليومي")
                }
            }

            Section("الأعضاء") {
                if report.members.isEmpty {
                    Text("لا توجد بيانات لهذا الشهر").foregroundStyle(.secondary)
                }
                ForEach(report.members) { stat in
                    MemberStatRow(stat: stat)
                }
            }

            if report.spendingByMeal.count > 1 {
                Section("حسب نوع الوجبة") {
                    ForEach(report.spendingByMeal, id: \.name) { item in
                        HStack {
                            Text(item.name)
                            Text("\(item.count) وجبة").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            MoneyText(money: item.amount)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                ShareLink(item: MonthlyReportBuilder.shareText(listName: snapshot.list.name, report: report)) {
                    Label("مشاركة كنص", systemImage: "text.bubble")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let pdfURL, !report.isEmpty {
                ShareLink(item: pdfURL, preview: SharePreview("تقرير \(month.arabicTitle)")) {
                    Label("تصدير PDF", systemImage: "doc.richtext")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .task(id: "\(month)-\(snapshot.records.count)-\(snapshot.payments.count)-\(report.totalSpent.halalas)") {
            renderPDF(report)
        }
        .alert("تعذّر إنشاء PDF", isPresented: .constant(pdfError != nil)) {
            Button("حسناً") { pdfError = nil }
        } message: {
            Text(pdfError ?? "")
        }
    }

    private var monthSwitcher: some View {
        HStack {
            Button {
                month = month.previous
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(month <= (months.last ?? month))

            Spacer()
            Menu {
                ForEach(months, id: \.self) { item in
                    Button(item.arabicTitle) { month = item }
                }
            } label: {
                Text(month.arabicTitle).font(.headline)
            }
            Spacer()

            Button {
                month = month.next
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(month >= Month.current())
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 4)
    }

    private func renderPDF(_ report: MonthlyReport) {
        guard !report.isEmpty else { pdfURL = nil; return }
        do {
            pdfURL = try ReportPDFRenderer.render(listName: snapshot.list.name, report: report)
        } catch {
            pdfURL = nil
            pdfError = error.localizedDescription
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: Money
    let color: Color
    var caption: String?

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            MoneyText(money: value, font: .title3, weight: .bold).foregroundStyle(color)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(.vertical, 8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MemberStatRow: View {
    let stat: MemberMonthStat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stat.member.emoji)
                Text(stat.member.name).font(.body.weight(.medium))
                Spacer()
                closing
            }
            HStack(spacing: 14) {
                detail("وجبات", text: "\(stat.mealCount)")
                if !stat.carriedIn.isZero { detail("سابق", money: stat.carriedIn) }
                detail("مصروف", money: stat.spent)
                detail("سداد", money: stat.paid)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var closing: some View {
        if stat.closing.isPositive {
            MoneyText(money: stat.closing, weight: .semibold).foregroundStyle(Color.owes)
        } else if stat.closing.isNegative {
            HStack(spacing: 4) {
                Text("له").font(.caption)
                MoneyText(money: stat.closing.magnitude, weight: .semibold)
            }
            .foregroundStyle(Color.credit)
        } else {
            Label("مسدّد", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.credit)
        }
    }

    private func detail(_ title: String, text: String) -> some View {
        HStack(spacing: 3) { Text(title); Text(text).monospacedDigit() }
    }

    private func detail(_ title: String, money: Money) -> some View {
        HStack(spacing: 3) { Text(title); Text(MoneyFormatter.number(money)).monospacedDigit() }
    }
}
