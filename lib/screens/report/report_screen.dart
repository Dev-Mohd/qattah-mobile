import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currency.dart';
import '../../core/report_pdf_service.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String listId;
  final bool embedded;
  const ReportScreen({super.key, required this.listId, this.embedded = false});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  String get _monthKey =>
      '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

  void _prevMonth() => setState(() {
        if (_selectedMonth == 1) {
          _selectedMonth = 12;
          _selectedYear--;
        } else {
          _selectedMonth--;
        }
      });

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth == now.month) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  String get _monthLabel {
    const names = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${names[_selectedMonth]} $_selectedYear';
  }

  String _money(double value, {int decimals = 0}) {
    final normalized = value.abs() < 0.005 ? 0.0 : value;
    return formatCurrency(normalized, decimals: decimals);
  }

  String _buildReportText(String listName, ReportData data) {
    final rows = data.stats.map((stat) {
      final remaining = stat.remaining;
      final status = remaining > 0
          ? 'متبقي ${_money(remaining)}'
          : remaining < 0
              ? 'رصيد زائد ${_money(remaining.abs())}'
              : 'مسدد';

      return '• ${stat.name}\n'
          '  المصروفات: ${_money(stat.total)} | السداد: ${_money(stat.paid)} | $status';
    }).join('\n');

    final netLabel = data.grandTotal > 0
        ? 'المتبقي المطلوب'
        : data.grandTotal < 0
            ? 'الرصيد الزائد'
            : 'المتبقي';

    final netValue = data.grandTotal < 0
        ? _money(data.grandTotal.abs())
        : _money(data.grandTotal);

    return 'تقرير قطه\n'
        'القائمة: $listName\n'
        'الشهر: $_monthLabel\n'
        '${'─' * 24}\n'
        'مصاريف الشهر: ${_money(data.expenseTotal)}\n'
        'السداد: ${_money(data.paymentTotal)}\n'
        '$netLabel: $netValue\n'
        'عدد الوجبات: ${data.recordCount}\n'
        'عدد السدادات: ${data.paymentCount}\n'
        '${'─' * 24}\n'
        'تفصيل الأعضاء:\n'
        '$rows\n'
        '${'─' * 24}\n'
        'تم إرساله من تطبيق قطه';
  }

  Future<void> _shareReport(String listName, ReportData data) async {
    await SharePlus.instance.share(
      ShareParams(
        text: _buildReportText(listName, data),
        subject: 'تقرير $_monthLabel',
      ),
    );
  }

  Future<void> _exportPdf(String listName, ReportData data) async {
    try {
      await const ReportPdfService().shareMonthlyReport(
        listName: listName,
        monthLabel: _monthLabel,
        monthKey: _monthKey,
        data: data,
        accentColor: context.accentColor,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDataProvider(
      ReportParams(listId: widget.listId, monthKey: _monthKey),
    ));
    final listsAsync = ref.watch(listsProvider);
    final listName = listsAsync.whenData((lists) {
          for (final list in lists) {
            if (list.id == widget.listId) return list.name;
          }
          return 'القائمة';
        }).valueOrNull ??
        'القائمة';

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('التقرير الشهري'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.goToList(widget.listId),
              ),
            ),
      body: reportAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(reportDataProvider(
              ReportParams(listId: widget.listId, monthKey: _monthKey))),
        ),
        data: (data) => FadeInWidget(
            child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePad,
            context.pagePad,
            context.pagePad,
            widget.embedded ? HesabnaSpacing.bottomNavPad : context.pagePad,
          ),
          children: [
            _MonthSelector(
              label: _monthLabel,
              onPrev: _prevMonth,
              onNext: _nextMonth,
              canNext: () {
                final n = DateTime.now();
                return !(_selectedYear == n.year && _selectedMonth == n.month);
              },
            ),
            const SizedBox(height: 14),
            _ReportHeroCard(data: data, monthLabel: _monthLabel),
            const SizedBox(height: 12),
            _StatsRow(data: data),
            if (data.stats.isEmpty) ...[
              const SizedBox(height: 16),
              const _EmptyMonth(),
            ] else ...[
              const SizedBox(height: 20),
              if (data.dailyTotals.isNotEmpty) ...[
                const _SectionLabel(text: 'الإجمالي اليومي'),
                const SizedBox(height: 10),
                _LineChartCard(dailyTotals: data.dailyTotals),
                const SizedBox(height: 20),
              ],
              if (data.dailyPaymentTotals.isNotEmpty) ...[
                const _SectionLabel(text: 'دفعات السداد'),
                const SizedBox(height: 10),
                _LineChartCard(
                  dailyTotals: data.dailyPaymentTotals,
                  color: HesabnaColors.lightSuccess,
                ),
                const SizedBox(height: 20),
              ],
              const _SectionLabel(text: 'إنفاق الأعضاء'),
              const SizedBox(height: 10),
              _BarChartCard(stats: data.stats),
              const SizedBox(height: 20),
              const _SectionLabel(text: 'تفصيل الأعضاء'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                    color: context.cCard,
                    borderRadius: BorderRadius.circular(HesabnaRadius.lg),
                    border: context.cardStyle == AppCardStyle.bordered
                        ? Border.all(color: context.cBorder)
                        : null),
                child: Column(
                  children: data.stats.asMap().entries.map((e) {
                    final i = e.key;
                    final stat = e.value;
                    return Column(children: [
                      _MemberStatRow(
                          stat: stat, maxDays: data.maxDays, rank: i + 1),
                      if (i < data.stats.length - 1)
                        const Divider(height: 1, indent: 16),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _shareReport(listName, data),
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: const Text('مشاركة واتساب'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _exportPdf(listName, data),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('تصدير PDF'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        )),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  LINE CHART
// ═══════════════════════════════════════════

class _LineChartCard extends StatefulWidget {
  final List<MapEntry<String, double>> dailyTotals;
  final Color? color;
  const _LineChartCard({required this.dailyTotals, this.color});

  @override
  State<_LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<_LineChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_LineChartCard old) {
    super.didUpdateWidget(old);
    // إعادة الـ animation عند تغيير الشهر
    if (old.dailyTotals != widget.dailyTotals) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = widget.dailyTotals
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final maxY =
        widget.dailyTotals.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final accent = widget.color ?? context.accentColor;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 200,
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(HesabnaRadius.lg),
            border: context.cardStyle == AppCardStyle.bordered
                ? Border.all(color: context.cBorder)
                : null),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: context.cBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: (widget.dailyTotals.length / 4)
                      .ceilToDouble()
                      .clamp(1, 999),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= widget.dailyTotals.length) {
                      return const SizedBox.shrink();
                    }
                    final day = widget.dailyTotals[i].key.split('-').last;
                    return Text(day,
                        style:
                            TextStyle(fontSize: 10, color: context.cTextSub));
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: context.cTextSub)),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.4,
                // gradient على الخط نفسه
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.5),
                    accent,
                    accent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, _) {
                    // نقطة فقط على آخر قيمة
                    return spot.x == spots.last.x;
                  },
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: accent,
                    strokeWidth: 2,
                    strokeColor: context.cSurface,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.18 * _anim.value),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  BAR CHART
// ═══════════════════════════════════════════

class _BarChartCard extends StatefulWidget {
  final List<MemberStat> stats;
  const _BarChartCard({required this.stats});

  @override
  State<_BarChartCard> createState() => _BarChartCardState();
}

class _BarChartCardState extends State<_BarChartCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_BarChartCard old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = widget.stats.isEmpty
        ? 1.0
        : widget.stats
            .map((s) => s.remaining.abs())
            .reduce((a, b) => a > b ? a : b);

    final accent = context.accentColor;

    final barGroups = widget.stats.asMap().entries.map((e) {
      final value = e.value.remaining.abs();
      final isTop = value == maxVal;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: value * _anim.value,
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: isTop
                  ? [accent, accent.withValues(alpha: 0.7)]
                  : [
                      accent.withValues(alpha: 0.25),
                      accent.withValues(alpha: 0.45),
                    ],
            ),
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 220,
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(HesabnaRadius.lg),
            border: context.cardStyle == AppCardStyle.bordered
                ? Border.all(color: context.cBorder)
                : null),
        child: BarChart(
          BarChartData(
            maxY: maxVal * 1.2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: context.cBorder, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= widget.stats.length) {
                      return const SizedBox.shrink();
                    }
                    final name = widget.stats[i].name.split(' ').first;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(name,
                          style:
                              TextStyle(fontSize: 10, color: context.cTextSub)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: context.cTextSub)),
                ),
              ),
            ),
            barGroups: barGroups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.cCard,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${widget.stats[group.x].name}\n${formatCurrency(rod.toY / _anim.value)} متبقي',
                  TextStyle(
                      color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ═══════════════════════════════════════════
//  MONTH SELECTOR
// ═══════════════════════════════════════════

class _MonthSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool Function() canNext;

  const _MonthSelector({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.canNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: context.cardStyle == AppCardStyle.bordered
              ? Border.all(color: context.cBorder)
              : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              onPressed: onPrev,
              icon: Icon(Icons.chevron_right, color: context.accentColor)),
          Text(label, style: HesabnaTypography.heading(color: context.cText)),
          IconButton(
            onPressed: canNext() ? onNext : null,
            icon: Icon(Icons.chevron_left,
                color: canNext() ? context.accentColor : context.cTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ReportHeroCard extends StatelessWidget {
  final ReportData data;
  final String monthLabel;

  const _ReportHeroCard({
    required this.data,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = data.grandTotal;
    final color = remaining > 0
        ? HesabnaColors.lightDanger
        : remaining < 0
            ? HesabnaColors.lightSuccess
            : context.accentColor;
    final label = remaining > 0
        ? 'المتبقي المطلوب'
        : remaining < 0
            ? 'رصيد زائد'
            : 'كل شيء مسدد';
    final progress = data.expenseTotal <= 0
        ? 0.0
        : (data.paymentTotal / data.expenseTotal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.xl),
        border: context.cardStyle == AppCardStyle.bordered
            ? Border.all(color: context.cBorder)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monthLabel,
                        style:
                            HesabnaTypography.caption(color: context.cTextSub)),
                    const SizedBox(height: 4),
                    Text(label,
                        style:
                            HesabnaTypography.subtitle(color: context.cText)),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(HesabnaRadius.md),
                ),
                child: Icon(Icons.analytics_outlined, color: color, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatCurrency(remaining.abs(), decimals: 2),
            textDirection: TextDirection.ltr,
            style: HesabnaTypography.amountHero(color: color),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(HesabnaRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.cHover,
              valueColor:
                  AlwaysStoppedAnimation<Color>(HesabnaColors.lightSuccess),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('تغطية السداد',
                  style: HesabnaTypography.caption(color: context.cTextSub)),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: HesabnaTypography.caption(color: context.cText)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  STATS ROW
// ═══════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final ReportData data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              width: itemWidth,
              label: 'المتبقي',
              value: formatCurrency(data.grandTotal),
              color: data.grandTotal > 0
                  ? HesabnaColors.lightDanger
                  : data.grandTotal < 0
                      ? HesabnaColors.lightSuccess
                      : context.accentColor,
            ),
            _StatCard(
              width: itemWidth,
              label: 'مصاريف الشهر',
              value: formatCurrency(data.expenseTotal),
              color: context.accentColor,
            ),
            _StatCard(
              width: itemWidth,
              label: 'السداد',
              value: formatCurrency(data.paymentTotal),
              color: HesabnaColors.lightSuccess,
            ),
            _StatCard(
              width: itemWidth,
              label: 'السجلات / الدفعات',
              value: '${data.recordCount} / ${data.paymentCount}',
              color: context.cText,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(HesabnaRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: HesabnaTypography.label(color: context.cTextSub)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  style: HesabnaTypography.amountSmall(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  MEMBER STAT ROW
// ═══════════════════════════════════════════

class _MemberStatRow extends StatelessWidget {
  final MemberStat stat;
  final int maxDays;
  final int rank;
  const _MemberStatRow(
      {required this.stat, required this.maxDays, required this.rank});

  @override
  Widget build(BuildContext context) {
    final progress = maxDays > 0 ? stat.days / maxDays : 0.0;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cHover,
                borderRadius: BorderRadius.circular(HesabnaRadius.sm),
              ),
              child: Text('$rank',
                  style: TextStyle(
                      color: context.cTextSub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(stat.name,
                    style: HesabnaTypography.subtitle(color: context.cText))),
            Text('${stat.days} يوم',
                style: HesabnaTypography.caption(color: context.cTextMuted)),
            const SizedBox(width: 12),
            Text(formatCurrency(stat.remaining),
                style: HesabnaTypography.amountSmall(
                    color: stat.remaining > 0
                        ? HesabnaColors.lightDanger
                        : stat.remaining < 0
                            ? HesabnaColors.lightSuccess
                            : context.accentColor)),
          ]),
          if (stat.total > 0 || stat.paid > 0) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (stat.total > 0)
                  _MiniTag(
                      label: 'مصاريف ${formatCurrency(stat.total)}',
                      color: context.accentColor),
                if (stat.paid > 0)
                  _MiniTag(
                      label: 'سداد ${formatCurrency(stat.paid)}',
                      color: HesabnaColors.lightSuccess),
              ],
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(HesabnaRadius.xs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.cHover,
              valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(HesabnaRadius.xs),
      ),
      child: Text(
        label,
        style: HesabnaTypography.caption(color: color)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: HesabnaTypography.label(color: context.cTextSub));
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.cHover,
                borderRadius: BorderRadius.circular(HesabnaRadius.lg),
              ),
              child: Icon(Icons.bar_chart_outlined,
                  size: 28, color: context.cTextMuted),
            ),
            const SizedBox(height: 16),
            Text('لا توجد بيانات لهذا الشهر',
                style: HesabnaTypography.subtitle(color: context.cText)),
            const SizedBox(height: 4),
            Text('جرّب شهراً آخر',
                style: HesabnaTypography.bodySm(color: context.cText)),
          ],
        ),
      ),
    );
  }
}
