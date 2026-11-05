import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'currency.dart';
import '../providers/report_provider.dart';

class ReportPdfService {
  const ReportPdfService();

  Future<void> shareMonthlyReport({
    required String listName,
    required String monthLabel,
    required String monthKey,
    required ReportData data,
    required Color accentColor,
  }) async {
    final bytes = await buildMonthlyReport(
      listName: listName,
      monthLabel: monthLabel,
      data: data,
      accentColor: accentColor,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'qattah-report-$monthKey.pdf',
    );
  }

  Future<void> shareMemberObligationReport({
    required String listName,
    required String memberName,
    required double openingBalance,
    required double spent,
    required double paid,
    required double remaining,
    required Color accentColor,
  }) async {
    final bytes = await buildMemberObligationReport(
      listName: listName,
      memberName: memberName,
      openingBalance: openingBalance,
      spent: spent,
      paid: paid,
      remaining: remaining,
      accentColor: accentColor,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'qattah-${_safeFileName(memberName)}-obligations.pdf',
    );
  }

  Future<Uint8List> buildMemberObligationReport({
    required String listName,
    required String memberName,
    required double openingBalance,
    required double spent,
    required double paid,
    required double remaining,
    required Color accentColor,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final riyal = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SaudiRiyal.ttf'),
    );
    final riyalBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SaudiRiyal-Bold.ttf'),
    );
    final latin = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final logoSvg = await rootBundle.loadString('assets/brand/qattah-logo.svg');

    const brandPrimary = PdfColor.fromInt(0xFF064E35);
    const brandAccent = PdfColor.fromInt(0xFF10B981);
    const ink = PdfColor.fromInt(0xFF111827);
    const muted = PdfColor.fromInt(0xFF64748B);
    const border = PdfColor.fromInt(0xFFDDEBE5);
    const surface = PdfColor.fromInt(0xFFF3FBF8);
    const success = PdfColor.fromInt(0xFF16A34A);
    const danger = PdfColor.fromInt(0xFFDC2626);

    final status = remaining > 0
        ? 'مبلغ مطلوب'
        : remaining < 0
            ? 'رصيد زائد'
            : 'مسدد بالكامل';
    final statusColor = remaining > 0
        ? danger
        : remaining < 0
            ? success
            : brandAccent;
    final generatedAt = DateTime.now().toIso8601String().substring(0, 10);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [riyal, riyalBold, latin],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _MemberPdfHeader(
              logoSvg: logoSvg,
              listName: listName,
              memberName: memberName,
              generatedAt: generatedAt,
              ink: brandPrimary,
              accent: brandAccent,
            ),
            pw.SizedBox(height: 18),
            _MemberStatusCard(
              status: status,
              remaining: remaining,
              color: statusColor,
              ink: ink,
              muted: muted,
              surface: surface,
              border: border,
            ),
            pw.SizedBox(height: 16),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricCard(
                  label: 'رصيد سابق',
                  value: _money(openingBalance),
                  color: openingBalance > 0 ? danger : success,
                  ink: ink,
                  muted: muted,
                  border: border,
                  surface: surface,
                ),
                _MetricCard(
                  label: 'مصاريف مسجلة',
                  value: _money(spent),
                  color: brandAccent,
                  ink: ink,
                  muted: muted,
                  border: border,
                  surface: surface,
                ),
                _MetricCard(
                  label: 'سداد',
                  value: _money(paid),
                  color: success,
                  ink: ink,
                  muted: muted,
                  border: border,
                  surface: surface,
                ),
                _MetricCard(
                  label: remaining >= 0 ? 'المتبقي' : 'الرصيد الزائد',
                  value: _money(remaining.abs()),
                  color: statusColor,
                  ink: ink,
                  muted: muted,
                  border: border,
                  surface: surface,
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            _SectionTitle('تفصيل الالتزام', brandPrimary, muted),
            pw.SizedBox(height: 8),
            _ObligationBreakdownTable(
              openingBalance: openingBalance,
              spent: spent,
              paid: paid,
              remaining: remaining,
              ink: ink,
              muted: muted,
              border: border,
              surface: surface,
              success: success,
              danger: danger,
            ),
            pw.Spacer(),
            _Footer(muted),
          ],
        ),
      ),
    );

    return doc.save();
  }

  Future<Uint8List> buildMonthlyReport({
    required String listName,
    required String monthLabel,
    required ReportData data,
    required Color accentColor,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final riyal = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SaudiRiyal.ttf'),
    );
    final riyalBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SaudiRiyal-Bold.ttf'),
    );
    final latin = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final logoSvg = await rootBundle.loadString('assets/brand/qattah-logo.svg');

    const brandPrimary = PdfColor.fromInt(0xFF064E35);
    const brandAccent = PdfColor.fromInt(0xFF10B981);
    const ink = PdfColor.fromInt(0xFF111827);
    const muted = PdfColor.fromInt(0xFF64748B);
    const border = PdfColor.fromInt(0xFFDDEBE5);
    const surface = PdfColor.fromInt(0xFFF3FBF8);
    const success = PdfColor.fromInt(0xFF16A34A);
    const danger = PdfColor.fromInt(0xFFDC2626);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [
          riyal,
          riyalBold,
          latin,
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _Header(
            listName: listName,
            monthLabel: monthLabel,
            logoSvg: logoSvg,
            accent: brandAccent,
            ink: brandPrimary,
          ),
          pw.SizedBox(height: 18),
          _SummaryGrid(
            data: data,
            accent: brandAccent,
            ink: ink,
            muted: muted,
            border: border,
            surface: surface,
            success: success,
          ),
          pw.SizedBox(height: 20),
          _SectionTitle('تفصيل الأعضاء', brandPrimary, muted),
          pw.SizedBox(height: 8),
          if (data.stats.isEmpty)
            _EmptyState(surface: surface, border: border, muted: muted)
          else
            _MembersTable(
              data: data,
              ink: ink,
              muted: muted,
              border: border,
              surface: surface,
              success: success,
              danger: danger,
            ),
          pw.SizedBox(height: 16),
          _Footer(muted),
        ],
      ),
    );

    return doc.save();
  }
}

class _MemberPdfHeader extends pw.StatelessWidget {
  final String logoSvg;
  final String listName;
  final String memberName;
  final String generatedAt;
  final PdfColor ink;
  final PdfColor accent;

  _MemberPdfHeader({
    required this.logoSvg,
    required this.listName,
    required this.memberName,
    required this.generatedAt,
    required this.ink,
    required this.accent,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: ink,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 60,
            height: 60,
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            child: pw.SvgImage(svg: logoSvg),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'بيان التزامات العضو',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$memberName · $listName',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFFCBD5E1),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              generatedAt,
              style: pw.TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberStatusCard extends pw.StatelessWidget {
  final String status;
  final double remaining;
  final PdfColor color;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor surface;
  final PdfColor border;

  _MemberStatusCard({
    required this.status,
    required this.remaining,
    required this.color,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.border,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: surface,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(status,
                    style: pw.TextStyle(color: muted, fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Text(
                  _money(remaining.abs()),
                  style: pw.TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 46,
            height: 46,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Center(
              child: pw.Text(
                remaining == 0 ? '✓' : '!',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObligationBreakdownTable extends pw.StatelessWidget {
  final double openingBalance;
  final double spent;
  final double paid;
  final double remaining;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor border;
  final PdfColor surface;
  final PdfColor success;
  final PdfColor danger;

  _ObligationBreakdownTable({
    required this.openingBalance,
    required this.spent,
    required this.paid,
    required this.remaining,
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
    required this.success,
    required this.danger,
  });

  @override
  pw.Widget build(pw.Context context) {
    final rows = [
      ('الرصيد السابق', openingBalance, openingBalance >= 0 ? danger : success),
      ('مصاريف الوجبات', spent, danger),
      ('السداد', paid, success),
      (
        remaining >= 0 ? 'المتبقي المطلوب' : 'الرصيد الزائد',
        remaining.abs(),
        remaining > 0 ? danger : success
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: surface),
          children: [
            _Cell('البند', bold: true, color: ink),
            _Cell('المبلغ', bold: true, color: ink),
          ],
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              _Cell(row.$1, color: muted),
              _Cell(_money(row.$2), color: row.$3, bold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends pw.StatelessWidget {
  final String listName;
  final String monthLabel;
  final String logoSvg;
  final PdfColor accent;
  final PdfColor ink;

  _Header({
    required this.listName,
    required this.monthLabel,
    required this.logoSvg,
    required this.accent,
    required this.ink,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: ink,
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 58,
            height: 58,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
            ),
            padding: const pw.EdgeInsets.all(4),
            child: pw.SvgImage(svg: logoSvg),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'قطه',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'تقرير شهري لمصاريف الوجبات المشتركة',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFFCBD5E1),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  listName,
                  style: pw.TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  monthLabel,
                  style: pw.TextStyle(color: accent, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends pw.StatelessWidget {
  final ReportData data;
  final PdfColor accent;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor border;
  final PdfColor surface;
  final PdfColor success;

  _SummaryGrid({
    required this.data,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
    required this.success,
  });

  @override
  pw.Widget build(pw.Context context) {
    final remainingColor = data.grandTotal > 0 ? accent : success;
    final remainingLabel = data.grandTotal > 0
        ? 'المتبقي المطلوب'
        : data.grandTotal < 0
            ? 'رصيد زائد'
            : 'المتبقي';

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricCard(
          label: 'مصاريف الشهر',
          value: _money(data.expenseTotal),
          color: accent,
          ink: ink,
          muted: muted,
          border: border,
          surface: surface,
        ),
        _MetricCard(
          label: 'السداد',
          value: _money(data.paymentTotal),
          color: success,
          ink: ink,
          muted: muted,
          border: border,
          surface: surface,
        ),
        _MetricCard(
          label: remainingLabel,
          value: _money(data.grandTotal.abs()),
          color: remainingColor,
          ink: ink,
          muted: muted,
          border: border,
          surface: surface,
        ),
        _MetricCard(
          label: 'النشاط',
          value: '${data.recordCount} وجبة / ${data.paymentCount} سداد',
          color: ink,
          ink: ink,
          muted: muted,
          border: border,
          surface: surface,
        ),
      ],
    );
  }
}

class _MetricCard extends pw.StatelessWidget {
  final String label;
  final String value;
  final PdfColor color;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor border;
  final PdfColor surface;

  _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      width: 126,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: surface,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: muted, fontSize: 9)),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends pw.StatelessWidget {
  final String title;
  final PdfColor ink;
  final PdfColor muted;

  _SectionTitle(this.title, this.ink, this.muted);

  @override
  pw.Widget build(pw.Context context) {
    return pw.Row(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: ink,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            height: 1,
            color: const PdfColor.fromInt(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }
}

class _MembersTable extends pw.StatelessWidget {
  final ReportData data;
  final PdfColor ink;
  final PdfColor muted;
  final PdfColor border;
  final PdfColor surface;
  final PdfColor success;
  final PdfColor danger;

  _MembersTable({
    required this.data,
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
    required this.success,
    required this.danger,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Table(
      border: pw.TableBorder.all(color: border, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.1),
        1: pw.FlexColumnWidth(1.25),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: surface),
          children: [
            _Cell('العضو', bold: true, color: ink),
            _Cell('المصاريف', bold: true, color: ink),
            _Cell('السداد', bold: true, color: ink),
            _Cell('المتبقي', bold: true, color: ink),
            _Cell('الحالة', bold: true, color: ink),
          ],
        ),
        ...data.stats.map((stat) {
          final status = stat.remaining > 0
              ? 'مطلوب'
              : stat.remaining < 0
                  ? 'زائد'
                  : 'مسدد';
          final statusColor = stat.remaining > 0 ? danger : success;

          return pw.TableRow(
            children: [
              _Cell(stat.name, color: ink),
              _Cell(_money(stat.total), color: muted),
              _Cell(_money(stat.paid), color: muted),
              _Cell(_money(stat.remaining.abs()), color: statusColor),
              _Cell(status, color: statusColor, bold: true),
            ],
          );
        }),
      ],
    );
  }
}

class _Cell extends pw.StatelessWidget {
  final String text;
  final bool bold;
  final PdfColor color;

  _Cell(this.text, {required this.color, this.bold = false});

  @override
  pw.Widget build(pw.Context context) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

class _EmptyState extends pw.StatelessWidget {
  final PdfColor surface;
  final PdfColor border;
  final PdfColor muted;

  _EmptyState({
    required this.surface,
    required this.border,
    required this.muted,
  });

  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: surface,
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Center(
        child: pw.Text(
          'لا توجد بيانات لهذا الشهر',
          style: pw.TextStyle(color: muted, fontSize: 12),
        ),
      ),
    );
  }
}

class _Footer extends pw.StatelessWidget {
  final PdfColor muted;

  _Footer(this.muted);

  @override
  pw.Widget build(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'تم إنشاء التقرير بواسطة تطبيق قطه',
        style: pw.TextStyle(color: muted, fontSize: 9),
      ),
    );
  }
}

String _money(double value) {
  return formatCurrency(value);
}

String _safeFileName(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
  return cleaned.isEmpty ? 'member' : cleaned;
}
