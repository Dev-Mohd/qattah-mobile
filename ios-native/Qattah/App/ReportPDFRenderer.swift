import UIKit
import QattahKit

/// Draws the monthly report as an A4 PDF (right-to-left Arabic layout).
enum ReportPDFRenderer {
    private static let page = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
    private static let margin: CGFloat = 36

    private static let brand = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1)   // #10B981
    private static let brandDark = UIColor(red: 0.02, green: 0.37, blue: 0.27, alpha: 1)
    private static let ink = UIColor(white: 0.12, alpha: 1)
    private static let muted = UIColor(white: 0.45, alpha: 1)
    private static let line = UIColor(white: 0.88, alpha: 1)
    private static let owes = UIColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 1)
    private static let credit = UIColor(red: 0.05, green: 0.55, blue: 0.36, alpha: 1)

    /// Renders the report to a temporary PDF file and returns its URL.
    static func render(listName: String, report: MonthlyReport) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "تقرير \(listName) — \(report.month.arabicTitle)",
            kCGPDFContextCreator as String: "قطّه",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)

        let safeName = listName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("قطه-\(safeName)-\(report.month).pdf")

        try renderer.writePDF(to: url) { context in
            var y = startPage(context, listName: listName, report: report, first: true)
            y = drawSummary(report, top: y)
            y += 24

            y = drawSectionTitle("تفصيل الأعضاء", top: y)
            y = drawTableHeader(top: y)
            if report.members.isEmpty {
                y = drawCentered("لا توجد بيانات لهذا الشهر", top: y + 16)
            }
            for (index, stat) in report.members.enumerated() {
                if y > page.height - margin - 60 {
                    drawFooter()
                    y = startPage(context, listName: listName, report: report, first: false)
                    y = drawTableHeader(top: y)
                }
                y = drawMemberRow(stat, top: y, shaded: index.isMultiple(of: 2))
            }

            if !report.spendingByMeal.isEmpty {
                y += 24
                if y > page.height - margin - 120 {
                    drawFooter()
                    y = startPage(context, listName: listName, report: report, first: false)
                }
                y = drawSectionTitle("حسب نوع الوجبة", top: y)
                for item in report.spendingByMeal {
                    if y > page.height - margin - 40 {
                        drawFooter()
                        y = startPage(context, listName: listName, report: report, first: false)
                    }
                    y = drawKeyValue(key: "\(item.name) (\(item.count) وجبة)",
                                     value: MoneyFormatter.plain(item.amount), top: y)
                }
            }
            drawFooter()
        }
        return url
    }

    // MARK: - Layout pieces

    private static func startPage(_ context: UIGraphicsPDFRendererContext, listName: String,
                                  report: MonthlyReport, first: Bool) -> CGFloat {
        context.beginPage()
        let headerHeight: CGFloat = first ? 96 : 44
        brandDark.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: 0, width: page.width, height: headerHeight)).fill()

        if first {
            draw("قطّه", font: .systemFont(ofSize: 26, weight: .black), color: .white,
                 in: CGRect(x: margin, y: 18, width: page.width - margin * 2, height: 34))
            draw("تقرير شهري لمصاريف الوجبات المشتركة", font: .systemFont(ofSize: 12, weight: .medium),
                 color: UIColor.white.withAlphaComponent(0.8),
                 in: CGRect(x: margin, y: 52, width: page.width - margin * 2, height: 18))
            draw("\(listName) · \(report.month.arabicTitle)", font: .systemFont(ofSize: 13, weight: .semibold),
                 color: .white, in: CGRect(x: margin, y: 52, width: page.width - margin * 2, height: 18),
                 alignment: .left)
        } else {
            draw("\(listName) · \(report.month.arabicTitle)", font: .systemFont(ofSize: 12, weight: .semibold),
                 color: .white, in: CGRect(x: margin, y: 14, width: page.width - margin * 2, height: 18))
        }
        return headerHeight + 24
    }

    private static func drawSummary(_ report: MonthlyReport, top: CGFloat) -> CGFloat {
        let tiles: [(String, String, UIColor)] = [
            ("مصاريف الشهر", MoneyFormatter.plain(report.totalSpent), ink),
            ("السداد", MoneyFormatter.plain(report.totalPaid), credit),
            ("المتبقي المطلوب", MoneyFormatter.plain(report.closingOwed), report.closingOwed.isPositive ? owes : ink),
            ("النشاط", "\(report.mealCount) وجبة / \(report.paymentCount) سداد", ink),
        ]
        let gap: CGFloat = 10
        let width = (page.width - margin * 2 - gap * 3) / 4
        let height: CGFloat = 62

        for (index, tile) in tiles.enumerated() {
            // Right-to-left: first tile on the right.
            let x = page.width - margin - CGFloat(index + 1) * width - CGFloat(index) * gap
            let rect = CGRect(x: x, y: top, width: width, height: height)
            UIColor(white: 0.97, alpha: 1).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
            draw(tile.0, font: .systemFont(ofSize: 9, weight: .medium), color: muted,
                 in: rect.insetBy(dx: 10, dy: 10).offsetBy(dx: 0, dy: 0), alignment: .center)
            draw(tile.1, font: .systemFont(ofSize: 13, weight: .bold), color: tile.2,
                 in: CGRect(x: rect.minX + 6, y: rect.minY + 30, width: rect.width - 12, height: 22), alignment: .center)
        }
        return top + height
    }

    private static func drawSectionTitle(_ title: String, top: CGFloat) -> CGFloat {
        draw(title, font: .systemFont(ofSize: 14, weight: .bold), color: brandDark,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 20))
        return top + 26
    }

    /// Columns, right to left: member, meals, carried, spent, paid, closing.
    private static let columns: [(title: String, width: CGFloat)] = [
        ("العضو", 150), ("الوجبات", 55), ("سابق", 70), ("المصروف", 70), ("السداد", 70), ("المتبقي", 108),
    ]

    private static func columnRects(top: CGFloat, height: CGFloat) -> [CGRect] {
        var x = page.width - margin
        return columns.map { column in
            x -= column.width
            return CGRect(x: x, y: top, width: column.width, height: height)
        }
    }

    private static func drawTableHeader(top: CGFloat) -> CGFloat {
        let height: CGFloat = 26
        brand.withAlphaComponent(0.12).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: top, width: page.width - margin * 2, height: height),
                     cornerRadius: 6).fill()
        for (index, pair) in zip(columnRects(top: top + 6, height: 16), columns).enumerated() {
            draw(pair.1.title, font: .systemFont(ofSize: 10, weight: .bold), color: brandDark,
                 in: pair.0.insetBy(dx: 6, dy: 0), alignment: index == 0 ? .right : .center)
        }
        return top + height
    }

    private static func drawMemberRow(_ stat: MemberMonthStat, top: CGFloat, shaded: Bool) -> CGFloat {
        let height: CGFloat = 26
        if shaded {
            UIColor(white: 0.985, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: margin, y: top, width: page.width - margin * 2, height: height)).fill()
        }
        let closingColor = stat.closing.isPositive ? owes : stat.closing.isNegative ? credit : muted
        let closingText: String
        if stat.closing.isPositive {
            closingText = "عليه \(MoneyFormatter.plain(stat.closing))"
        } else if stat.closing.isNegative {
            closingText = "له \(MoneyFormatter.plain(stat.closing.magnitude))"
        } else {
            closingText = "مسدّد"
        }

        let values: [(String, UIColor, NSTextAlignment)] = [
            (stat.member.name, ink, .right),
            ("\(stat.mealCount)", ink, .center),
            (MoneyFormatter.number(stat.carriedIn), muted, .center),
            (MoneyFormatter.number(stat.spent), ink, .center),
            (MoneyFormatter.number(stat.paid), credit, .center),
            (closingText, closingColor, .center),
        ]
        for (rect, value) in zip(columnRects(top: top + 6, height: 16), values) {
            draw(value.0, font: .systemFont(ofSize: 10, weight: value.1 == ink ? .regular : .semibold),
                 color: value.1, in: rect.insetBy(dx: 6, dy: 0), alignment: value.2)
        }
        line.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: top + height))
        path.addLine(to: CGPoint(x: page.width - margin, y: top + height))
        path.lineWidth = 0.5
        path.stroke()
        return top + height
    }

    private static func drawKeyValue(key: String, value: String, top: CGFloat) -> CGFloat {
        draw(key, font: .systemFont(ofSize: 11), color: ink,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 18))
        draw(value, font: .systemFont(ofSize: 11, weight: .semibold), color: ink,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 18), alignment: .left)
        return top + 22
    }

    private static func drawCentered(_ text: String, top: CGFloat) -> CGFloat {
        draw(text, font: .systemFont(ofSize: 12), color: muted,
             in: CGRect(x: margin, y: top, width: page.width - margin * 2, height: 20), alignment: .center)
        return top + 28
    }

    private static func drawFooter() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        draw("تم إنشاء التقرير بواسطة تطبيق قطّه · \(formatter.string(from: .now))",
             font: .systemFont(ofSize: 8), color: muted,
             in: CGRect(x: margin, y: page.height - margin + 8, width: page.width - margin * 2, height: 12),
             alignment: .center)
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect,
                             alignment: NSTextAlignment = .right) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = .rightToLeft
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ]).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }
}
