import UIKit
import SwiftUI
import QattahKit

/// A one-member "كشف حساب" PDF: big balance, breakdown, a small monthly
/// chart, the meals and payments behind the number, and where to pay.
/// Designed to be sent to the member on WhatsApp.
@MainActor
enum MemberStatementRenderer {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 36

    private static let brand = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1)
    private static let brandDark = UIColor(red: 0.02, green: 0.37, blue: 0.27, alpha: 1)
    private static let brandDeep = UIColor(red: 0.01, green: 0.18, blue: 0.14, alpha: 1)
    private static let ink = UIColor(white: 0.12, alpha: 1)
    private static let muted = UIColor(white: 0.45, alpha: 1)
    private static let line = UIColor(white: 0.9, alpha: 1)
    private static let soft = UIColor(white: 0.965, alpha: 1)
    private static let owes = UIColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1)
    private static let credit = UIColor(red: 0.05, green: 0.55, blue: 0.36, alpha: 1)

    static func render(snapshot: ListSnapshot, member: Member, balance: MemberBalance,
                       payment: PaymentDetails) throws -> URL {
        let meals = snapshot.meals(attendedBy: member)
        let payments = snapshot.payments(of: member)
        let logo = logoImage()

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "كشف حساب \(member.name)",
                               kCGPDFContextCreator as String: "قطّه"]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        let safeName = member.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("كشف-\(safeName)-\(Day.today()).pdf")

        try renderer.writePDF(to: url) { context in
            var y = header(context, member: member, listName: snapshot.list.name, logo: logo)
            y = balanceCard(balance, top: y)
            y = breakdown(balance, top: y + 14)
            y = monthlyChart(meals: meals, top: y + 22)

            // Meals
            y += 24
            y = sectionTitle("الوجبات (\(meals.count))", top: y)
            y = tableHeader(["التاريخ", "الوجبة", "النصيب"], top: y)
            for (index, item) in meals.enumerated() {
                if y > page.height - margin - 50 {
                    footer()
                    y = continuation(context, member: member, listName: snapshot.list.name)
                    y = tableHeader(["التاريخ", "الوجبة", "النصيب"], top: y)
                }
                y = tableRow([item.record.day.description, item.record.mealName, MoneyFormatter.plain(item.share)],
                             colors: [muted, ink, ink], top: y, shaded: index.isMultiple(of: 2))
            }
            if meals.isEmpty { y = note("لا توجد وجبات", top: y + 6) }

            // Payments
            y += 22
            if y > page.height - margin - 110 {
                footer()
                y = continuation(context, member: member, listName: snapshot.list.name)
            }
            y = sectionTitle("السدادات (\(payments.count))", top: y)
            y = tableHeader(["التاريخ", "ملاحظة", "المبلغ"], top: y)
            for (index, item) in payments.enumerated() {
                if y > page.height - margin - 50 {
                    footer()
                    y = continuation(context, member: member, listName: snapshot.list.name)
                    y = tableHeader(["التاريخ", "ملاحظة", "المبلغ"], top: y)
                }
                y = tableRow([item.paidOn.description, item.note.isEmpty ? "سداد" : item.note,
                              MoneyFormatter.plain(item.amount)],
                             colors: [muted, ink, credit], top: y, shaded: index.isMultiple(of: 2))
            }
            if payments.isEmpty { y = note("لا توجد سدادات", top: y + 6) }

            // Where to pay
            if balance.status == .owes && !payment.isEmpty {
                y += 24
                if y > page.height - margin - 130 {
                    footer()
                    y = continuation(context, member: member, listName: snapshot.list.name)
                }
                _ = paymentBox(payment, amount: balance.net, top: y)
            }
            footer()
        }
        return url
    }

    // MARK: - Header & cards

    private static func header(_ context: UIGraphicsPDFRendererContext, member: Member, listName: String,
                               logo: UIImage?) -> CGFloat {
        context.beginPage()
        let height: CGFloat = 150
        let rect = CGRect(x: 0, y: 0, width: page.width, height: height)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [brandDark.cgColor, brandDeep.cgColor] as CFArray, locations: [0, 1]) {
            context.cgContext.saveGState()
            context.cgContext.addRect(rect)
            context.cgContext.clip()
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: page.width, y: height), options: [])
            // soft glow
            brand.withAlphaComponent(0.25).setFill()
            UIBezierPath(ovalIn: CGRect(x: -60, y: -90, width: 260, height: 220)).fill()
            context.cgContext.restoreGState()
        }

        logo?.draw(in: CGRect(x: margin, y: 30, width: 64, height: 64))
        draw("كشف حساب", font: .systemFont(ofSize: 13, weight: .semibold),
             color: UIColor.white.withAlphaComponent(0.75), in: CGRect(x: margin, y: 30, width: page.width - margin * 2, height: 18))
        draw("\(member.emoji) \(member.name)", font: .systemFont(ofSize: 30, weight: .black), color: .white,
             in: CGRect(x: margin, y: 50, width: page.width - margin * 2 - 80, height: 40))
        draw("قطّة \(listName) · حتى \(Day.today())", font: .systemFont(ofSize: 12, weight: .medium),
             color: UIColor.white.withAlphaComponent(0.8), in: CGRect(x: margin, y: 96, width: page.width - margin * 2, height: 18))
        return height + 22
    }

    private static func continuation(_ context: UIGraphicsPDFRendererContext, member: Member, listName: String) -> CGFloat {
        context.beginPage()
        brandDark.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: page.width, height: 40)).fill()
        draw("كشف حساب \(member.name) · \(listName)", font: .systemFont(ofSize: 11, weight: .semibold),
             color: .white, in: CGRect(x: margin, y: 12, width: page.width - margin * 2, height: 16))
        return 64
    }

    private static func balanceCard(_ balance: MemberBalance, top: CGFloat) -> CGFloat {
        let rect = CGRect(x: margin, y: top, width: page.width - margin * 2, height: 92)
        let color: UIColor = balance.status == .owes ? owes : balance.status == .credit ? credit : brandDark
        color.withAlphaComponent(0.08).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 16).fill()
        color.setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.maxX - 6, y: rect.minY, width: 6, height: rect.height),
                     byRoundingCorners: [.topRight, .bottomRight], cornerRadii: CGSize(width: 16, height: 16)).fill()

        let title: String
        let amount: String
        switch balance.status {
        case .owes: title = "المتبقي عليك"; amount = MoneyFormatter.plain(balance.net)
        case .credit: title = "رصيدك الزائد"; amount = MoneyFormatter.plain(balance.net.magnitude)
        case .settled: title = "حسابك"; amount = "مسدّد بالكامل ✓"
        }
        draw(title, font: .systemFont(ofSize: 13, weight: .medium), color: muted,
             in: CGRect(x: rect.minX + 20, y: rect.minY + 16, width: rect.width - 40, height: 18))
        draw(amount, font: .systemFont(ofSize: 34, weight: .heavy), color: color,
             in: CGRect(x: rect.minX + 20, y: rect.minY + 36, width: rect.width - 40, height: 44))
        draw("\(balance.mealCount) وجبة", font: .systemFont(ofSize: 12, weight: .semibold), color: muted,
             in: CGRect(x: rect.minX + 20, y: rect.minY + 52, width: rect.width - 40, height: 18), alignment: .left)
        return rect.maxY
    }

    private static func breakdown(_ balance: MemberBalance, top: CGFloat) -> CGFloat {
        var items: [(String, Money, UIColor)] = [("الوجبات", balance.spent, ink), ("السداد", balance.paid, credit)]
        if !balance.openingBalance.isZero { items.insert(("رصيد سابق", balance.openingBalance, muted), at: 0) }
        let gap: CGFloat = 10
        let width = (page.width - margin * 2 - gap * CGFloat(items.count - 1)) / CGFloat(items.count)
        for (index, item) in items.enumerated() {
            let x = page.width - margin - CGFloat(index + 1) * width - CGFloat(index) * gap
            let rect = CGRect(x: x, y: top, width: width, height: 54)
            soft.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 12).fill()
            draw(item.0, font: .systemFont(ofSize: 10, weight: .medium), color: muted,
                 in: CGRect(x: rect.minX, y: rect.minY + 9, width: rect.width, height: 14), alignment: .center)
            draw(MoneyFormatter.plain(item.1), font: .systemFont(ofSize: 15, weight: .bold), color: item.2,
                 in: CGRect(x: rect.minX, y: rect.minY + 26, width: rect.width, height: 20), alignment: .center)
        }
        return top + 54
    }

    /// Bars of the member's share per month, last 6 months.
    private static func monthlyChart(meals: [(record: MealRecord, share: Money)], top: CGFloat) -> CGFloat {
        var months: [Month] = [Month.current()]
        while months.count < 6 { months.insert(months[0].previous, at: 0) }
        let totals = months.map { month in
            meals.filter { month.contains($0.record.day) }.map(\.share).sum()
        }
        guard let maxValue = totals.map(\.halalas).max(), maxValue > 0 else { return top }

        let titleBottom = sectionTitle("مصروفك في آخر 6 أشهر", top: top)
        let chartHeight: CGFloat = 90
        let width = page.width - margin * 2
        let slot = width / CGFloat(months.count)
        for (index, month) in months.enumerated() {
            // Right-to-left: oldest month on the right.
            let x = page.width - margin - CGFloat(index + 1) * slot
            let barHeight = max(3, chartHeight * CGFloat(totals[index].halalas) / CGFloat(maxValue))
            let barRect = CGRect(x: x + slot * 0.22, y: titleBottom + chartHeight - barHeight,
                                 width: slot * 0.56, height: barHeight)
            (index == months.count - 1 ? brand : brand.withAlphaComponent(0.45)).setFill()
            UIBezierPath(roundedRect: barRect, cornerRadius: 6).fill()
            if totals[index].isPositive {
                draw(MoneyFormatter.number(totals[index]), font: .systemFont(ofSize: 9, weight: .semibold), color: ink,
                     in: CGRect(x: x, y: barRect.minY - 14, width: slot, height: 12), alignment: .center)
            }
            let name = month.arabicTitle.split(separator: " ").first.map(String.init) ?? ""
            draw(name, font: .systemFont(ofSize: 9), color: muted,
                 in: CGRect(x: x, y: titleBottom + chartHeight + 4, width: slot, height: 12), alignment: .center)
        }
        return titleBottom + chartHeight + 18
    }

    private static func paymentBox(_ details: PaymentDetails, amount: Money, top: CGFloat) -> CGFloat {
        let lines = details.messageLines.dropFirst() // skip the "💳 للتحويل:" heading
        let height = CGFloat(44 + lines.count * 20)
        let rect = CGRect(x: margin, y: top, width: page.width - margin * 2, height: height)
        brand.withAlphaComponent(0.08).setFill()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
        path.fill()
        brand.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.setLineDash([5, 4], count: 2, phase: 0)
        path.stroke()

        draw("للتحويل · المبلغ المطلوب \(MoneyFormatter.plain(amount))", font: .systemFont(ofSize: 13, weight: .bold),
             color: brandDark, in: CGRect(x: rect.minX + 16, y: rect.minY + 14, width: rect.width - 32, height: 18))
        var y = rect.minY + 38
        for text in lines {
            draw(text, font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium), color: ink,
                 in: CGRect(x: rect.minX + 16, y: y, width: rect.width - 32, height: 16))
            y += 20
        }
        return rect.maxY
    }

    // MARK: - Tables

    private static func sectionTitle(_ title: String, top: CGFloat) -> CGFloat {
        draw(title, font: .systemFont(ofSize: 14, weight: .bold), color: brandDark,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 20))
        return top + 26
    }

    private static let columnWidths: [CGFloat] = [120, 283, 120] // date, description, amount (RTL)

    private static func columns(top: CGFloat) -> [CGRect] {
        var x = page.width - margin
        return columnWidths.map { width in
            x -= width
            return CGRect(x: x, y: top, width: width, height: 16)
        }
    }

    private static func tableHeader(_ titles: [String], top: CGFloat) -> CGFloat {
        brand.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 24),
                     cornerRadius: 6).fill()
        for (index, pair) in zip(columns(top: top + 5), titles).enumerated() {
            draw(pair.1, font: .systemFont(ofSize: 10, weight: .bold), color: brandDark,
                 in: pair.0.insetBy(dx: 8, dy: 0), alignment: index == 2 ? .left : .right)
        }
        return top + 24
    }

    private static func tableRow(_ values: [String], colors: [UIColor], top: CGFloat, shaded: Bool) -> CGFloat {
        let height: CGFloat = 24
        if shaded {
            UIColor(white: 0.985, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: top, width: page.width - margin * 2, height: height)).fill()
        }
        for (index, rect) in columns(top: top + 5).enumerated() {
            draw(values[index], font: .systemFont(ofSize: 10, weight: index == 2 ? .semibold : .regular),
                 color: colors[index], in: rect.insetBy(dx: 8, dy: 0), alignment: index == 2 ? .left : .right)
        }
        line.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: top + height))
        path.addLine(to: CGPoint(x: page.width - margin, y: top + height))
        path.lineWidth = 0.5
        path.stroke()
        return top + height
    }

    private static func note(_ text: String, top: CGFloat) -> CGFloat {
        draw(text, font: .systemFont(ofSize: 11), color: muted,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 16), alignment: .center)
        return top + 22
    }

    private static func footer() {
        draw("أُنشئ بواسطة تطبيق قطّه · راجع المبالغ وتواصل مع منظّم القطة لأي ملاحظة",
             font: .systemFont(ofSize: 8), color: muted,
             in: CGRect(x: margin, y: page.height - margin + 8, width: page.width - margin * 2, height: 12),
             alignment: .center)
    }

    // MARK: - Helpers

    private static func logoImage() -> UIImage? {
        let renderer = ImageRenderer(content: QattahLogoMark(size: 128))
        renderer.scale = 3
        return renderer.uiImage
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect,
                             alignment: NSTextAlignment = .right) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = .rightToLeft
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            .draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }
}
