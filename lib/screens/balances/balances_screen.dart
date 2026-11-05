import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/report_pdf_service.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/member_model.dart';
import '../../models/payment_model.dart';
import '../../widgets/app_widgets.dart';
import '../../providers/providers.dart';

class BalancesScreen extends ConsumerStatefulWidget {
  final String listId;
  final bool embedded;
  const BalancesScreen(
      {super.key, required this.listId, this.embedded = false});

  @override
  ConsumerState<BalancesScreen> createState() => _BalancesScreenState();
}

enum _BalanceFilter { all, debit, credit }

class _BalancesScreenState extends ConsumerState<BalancesScreen> {
  String _query = '';
  _BalanceFilter _filter = _BalanceFilter.all;
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final listName = ref.watch(listsProvider).maybeWhen(
          data: (lists) {
            for (final list in lists) {
              if (list.id == widget.listId) return list.name;
            }
            return 'القائمة';
          },
          orElse: () => 'القائمة',
        );
    final membersAsync = ref.watch(membersProvider(widget.listId));
    final recordsAsync = ref.watch(recordsProvider(widget.listId));
    final participantsAsync = ref.watch(allParticipantsProvider(widget.listId));
    final paymentsAsync = ref.watch(paymentsProvider(widget.listId));

    final body = membersAsync.when(
      loading: () => const AppLoadingView(),
      error: (e, _) => AppErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(membersProvider(widget.listId)),
      ),
      data: (members) {
        final spentMap = <String, double>{};
        final paidMap = <String, double>{};
        final recordIds =
            (recordsAsync.valueOrNull ?? []).map((record) => record.id).toSet();
        final participants = participantsAsync.valueOrNull ?? [];
        final payments = paymentsAsync.valueOrNull ?? [];
        for (final p in participants) {
          if (!recordIds.contains(p.recordId)) continue;
          final key =
              (p.memberId?.isNotEmpty ?? false) ? p.memberId! : p.memberName;
          spentMap[key] = (spentMap[key] ?? 0) + p.share;
        }
        for (final payment in payments) {
          final memberId = payment.memberId;
          if (memberId == null) continue;
          paidMap[memberId] = (paidMap[memberId] ?? 0) + payment.amount;
        }

        if (members.isEmpty) {
          return const AppEmptyView(
            icon: Icons.account_balance_wallet_outlined,
            label: 'لا يوجد أعضاء بعد',
            sub: 'أضف أعضاء من تبويب القائمة',
          );
        }

        // حساب الإجمالي لكل عضو
        final allRows = members.map((m) {
          final spent = (spentMap[m.id] ?? 0) + (spentMap[m.name] ?? 0);
          final paid = paidMap[m.id] ?? 0;
          final total = m.openingBalance + spent - paid;
          return _BalanceRow(member: m, spent: spent, paid: paid, total: total);
        }).toList();

        // تطبيق البحث والفلتر
        var filtered = allRows;
        if (_query.isNotEmpty) {
          final q = _query.trim().toLowerCase();
          filtered = filtered
              .where((r) => r.member.name.toLowerCase().contains(q))
              .toList();
        }
        switch (_filter) {
          case _BalanceFilter.debit:
            filtered = filtered.where((r) => r.total > 0).toList();
            break;
          case _BalanceFilter.credit:
            filtered = filtered.where((r) => r.total < 0).toList();
            break;
          case _BalanceFilter.all:
            break;
        }

        // ترتيب تنازلي
        filtered.sort((a, b) => b.total.compareTo(a.total));

        final grandTotal = allRows.fold<double>(0, (s, r) => s + r.total);

        return Column(
          children: [
            // ── Search bar ──────────────────────────────────────
            if (_showSearch || widget.embedded)
              Padding(
                padding: EdgeInsets.fromLTRB(context.pagePad,
                    widget.embedded ? context.pagePad : 8, context.pagePad, 0),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cHover,
                    borderRadius: BorderRadius.circular(HesabnaRadius.md),
                    border: Border.all(color: context.cBorder),
                  ),
                  child: TextField(
                    autofocus: !widget.embedded,
                    onChanged: (v) => setState(() => _query = v),
                    style: HesabnaTypography.bodySm(color: context.cText),
                    decoration: InputDecoration(
                      hintText: 'بحث باسم العضو...',
                      hintStyle: HesabnaTypography.bodySm(color: context.cText)
                          .copyWith(color: context.cTextMuted),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 16, color: context.cTextMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

            // ── Filter chips ────────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                    horizontal: context.pagePad, vertical: 6),
                children: [
                  _BalanceChip(
                    label: 'الكل',
                    active: _filter == _BalanceFilter.all,
                    onTap: () => setState(() => _filter = _BalanceFilter.all),
                  ),
                  _BalanceChip(
                    label: 'مدين',
                    active: _filter == _BalanceFilter.debit,
                    color: HesabnaColors.lightDanger,
                    onTap: () => setState(() => _filter = _BalanceFilter.debit),
                  ),
                  _BalanceChip(
                    label: 'دائن',
                    active: _filter == _BalanceFilter.credit,
                    color: HesabnaColors.lightSuccess,
                    onTap: () =>
                        setState(() => _filter = _BalanceFilter.credit),
                  ),
                ],
              ),
            ),

            // ── المحتوى ─────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? AppEmptyView(
                      icon: Icons.search_off_rounded,
                      label: 'لا توجد نتائج',
                      sub: _query.isNotEmpty
                          ? 'جرب اسماً مختلفاً'
                          : 'لا يوجد أعضاء بهذا التصنيف',
                    )
                  : FadeInWidget(
                      child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePad,
                        context.pagePad,
                        context.pagePad,
                        widget.embedded
                            ? HesabnaSpacing.bottomNavPad
                            : context.pagePad,
                      ),
                      children: [
                        _TotalCard(total: grandTotal, count: members.length),
                        const SizedBox(height: 12),
                        _BalanceDistributionCard(rows: allRows),
                        SizedBox(height: context.sectionGap),
                        Text('تفصيل الأعضاء',
                            style: HesabnaTypography.heading(
                                color: context.cText)),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                              color: context.cCard,
                              borderRadius:
                                  BorderRadius.circular(HesabnaRadius.lg),
                              border: context.cardStyle == AppCardStyle.bordered
                                  ? Border.all(color: context.cBorder)
                                  : null),
                          clipBehavior: Clip.hardEdge,
                          child: Column(
                            children: filtered.asMap().entries.map((e) {
                              final i = e.key;
                              final r = e.value;
                              return Column(children: [
                                _MemberBalanceRow(
                                  name: r.member.name,
                                  openingBalance: r.member.openingBalance,
                                  spent: r.spent,
                                  paid: r.paid,
                                  total: r.total,
                                  onSharePdf: () =>
                                      _shareMemberPdf(context, listName, r),
                                  onPay: r.total > 0
                                      ? () => _showPaymentSheet(context, ref, r)
                                      : null,
                                ),
                                if (i < filtered.length - 1)
                                  Divider(
                                      height: 1,
                                      indent: 16,
                                      color: context.cDivider),
                              ]);
                            }).toList(),
                          ),
                        ),
                        if (payments.isNotEmpty) ...[
                          SizedBox(height: context.sectionGap),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'سجل السدادات',
                                  style: HesabnaTypography.heading(
                                      color: context.cText),
                                ),
                              ),
                              Text(
                                formatCurrency(payments.fold<double>(
                                    0, (s, p) => s + p.amount)),
                                style: HesabnaTypography.amountSmall(
                                    color: HesabnaColors.lightSuccess),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _PaymentsSection(
                            payments: payments,
                            onEdit: (payment) =>
                                _showEditPaymentSheet(context, payment),
                            onDelete: (payment) =>
                                _confirmDeletePayment(context, ref, payment),
                          ),
                        ],
                        SizedBox(height: context.sectionGap),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.cHover,
                            borderRadius:
                                BorderRadius.circular(HesabnaRadius.md),
                            border: Border.all(color: context.cBorder),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline,
                                size: 14, color: context.cTextSub),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'الإجمالي = الرصيد السابق + مصاريف الوجبات - السداد',
                                style: HesabnaTypography.caption(
                                    color: context.cTextMuted),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    )),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: HesabnaTypography.body(color: context.cText),
                decoration: const InputDecoration(
                  hintText: 'بحث باسم العضو...',
                  border: InputBorder.none,
                ),
              )
            : const Text('الأرصدة'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _query = '';
            }),
          ),
        ],
      ),
      body: body,
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, _BalanceRow row) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (_) => _PaymentSheet(member: row.member, remaining: row.total),
    );
  }

  Future<void> _shareMemberPdf(
    BuildContext context,
    String listName,
    _BalanceRow row,
  ) async {
    try {
      await const ReportPdfService().shareMemberObligationReport(
        listName: listName,
        memberName: row.member.name,
        openingBalance: row.member.openingBalance,
        spent: row.spent,
        paid: row.paid,
        remaining: row.total,
        accentColor: context.accentColor,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء PDF للعضو: $e')),
      );
    }
  }

  void _showEditPaymentSheet(BuildContext context, PaymentModel payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (_) => _EditPaymentSheet(payment: payment),
    );
  }

  Future<void> _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    PaymentModel payment,
  ) async {
    final deleted = await ref
        .read(paymentNotifierProvider.notifier)
        .deletePayment(payment.id, payment.listId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'تم حذف السداد'
              : ref.read(paymentNotifierProvider).error ?? 'تعذر حذف السداد',
        ),
        action: deleted
            ? SnackBarAction(
                label: 'تراجع',
                onPressed: () {
                  ref
                      .read(paymentNotifierProvider.notifier)
                      .restorePayment(payment);
                },
              )
            : null,
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  BALANCE ROW DATA
// ═══════════════════════════════════════════

class _BalanceRow {
  final MemberModel member;
  final double spent;
  final double paid;
  final double total;
  const _BalanceRow({
    required this.member,
    required this.spent,
    required this.paid,
    required this.total,
  });
}

// ═══════════════════════════════════════════
//  BALANCE CHIP
// ═══════════════════════════════════════════

class _BalanceChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _BalanceChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.accentColor;
    return TapScaleWrapper(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          border: Border.all(
            color: active ? c : context.cBorder,
          ),
        ),
        child: Text(
          label,
          style: HesabnaTypography.caption(
            color: active ? c : context.cTextSub,
          ).copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w400),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    final color = total == 0
        ? context.cTextSub
        : total > 0
            ? HesabnaColors.lightDanger
            : HesabnaColors.lightSuccess;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: context.cardStyle == AppCardStyle.bordered
              ? Border.all(color: context.cBorder)
              : null),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الإجمالي الكلي',
                    style: HesabnaTypography.label(color: context.cTextSub)),
                const SizedBox(height: 6),
                Text(formatCurrency(total),
                    style: HesabnaTypography.amountLarge(color: color)),
                const SizedBox(height: 4),
                Text('$count أعضاء',
                    style:
                        HesabnaTypography.caption(color: context.cTextMuted)),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.cHover,
              borderRadius: BorderRadius.circular(HesabnaRadius.lg),
            ),
            child: Icon(Icons.account_balance_wallet_outlined,
                color: context.cTextSub, size: 22),
          ),
        ],
      ),
    );
  }
}

class _BalanceDistributionCard extends StatelessWidget {
  final List<_BalanceRow> rows;
  const _BalanceDistributionCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final debitRows = rows.where((r) => r.total > 0.005).toList();
    final creditRows = rows.where((r) => r.total < -0.005).toList();
    final settledRows = rows.length - debitRows.length - creditRows.length;
    final debitTotal = debitRows.fold<double>(0, (sum, r) => sum + r.total);
    final creditTotal =
        creditRows.fold<double>(0, (sum, r) => sum + r.total.abs());
    final settledValue = settledRows == 0 ? 0.0 : rows.length * 0.08;
    final hasData = debitTotal > 0 || creditTotal > 0 || settledRows > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        border: context.cardStyle == AppCardStyle.bordered
            ? Border.all(color: context.cBorder)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            height: 94,
            child: hasData
                ? PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 30,
                      sectionsSpace: 3,
                      borderData: FlBorderData(show: false),
                      sections: [
                        if (debitTotal > 0)
                          PieChartSectionData(
                            value: debitTotal,
                            color: HesabnaColors.lightDanger,
                            radius: 12,
                            showTitle: false,
                          ),
                        if (creditTotal > 0)
                          PieChartSectionData(
                            value: creditTotal,
                            color: HesabnaColors.lightSuccess,
                            radius: 12,
                            showTitle: false,
                          ),
                        if (settledRows > 0)
                          PieChartSectionData(
                            value: settledValue,
                            color: context.cBorder,
                            radius: 12,
                            showTitle: false,
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                  )
                : Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cBorder, width: 10),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('توزيع الأرصدة',
                    style: HesabnaTypography.subtitle(color: context.cText)),
                const SizedBox(height: 4),
                Text('لمحة سريعة عن المدين والدائن والمسدد',
                    style: HesabnaTypography.caption(color: context.cTextSub)),
                const SizedBox(height: 12),
                _DistributionLegend(
                  color: HesabnaColors.lightDanger,
                  label: 'مدين',
                  value: '${debitRows.length} · ${formatCurrency(debitTotal)}',
                ),
                const SizedBox(height: 6),
                _DistributionLegend(
                  color: HesabnaColors.lightSuccess,
                  label: 'دائن',
                  value:
                      '${creditRows.length} · ${formatCurrency(creditTotal)}',
                ),
                const SizedBox(height: 6),
                _DistributionLegend(
                  color: context.cTextMuted,
                  label: 'مسدد',
                  value: '$settledRows',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _DistributionLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: HesabnaTypography.caption(color: context.cTextSub)),
        const Spacer(),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: HesabnaTypography.caption(color: context.cText)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  MEMBER BALANCE ROW
// ═══════════════════════════════════════════

class _MemberBalanceRow extends StatelessWidget {
  final String name;
  final double openingBalance, spent, paid, total;
  final VoidCallback? onPay;
  final VoidCallback onSharePdf;
  const _MemberBalanceRow({
    required this.name,
    required this.openingBalance,
    required this.spent,
    required this.paid,
    required this.total,
    required this.onPay,
    required this.onSharePdf,
  });

  @override
  Widget build(BuildContext context) {
    final totalColor = total > 0
        ? HesabnaColors.lightDanger
        : total < 0
            ? HesabnaColors.lightSuccess
            : context.cTextSub;

    return TapScaleWrapper(
      onTap: () => _showMemberActions(context),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: context.cHover,
                    child: Text(
                      name.isNotEmpty ? name[0] : '؟',
                      style: HesabnaTypography.caption(color: context.cTextSub)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              HesabnaTypography.subtitle(color: context.cText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'اضغط للخيارات',
                          style: HesabnaTypography.caption(
                            color: context.cTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(formatCurrency(total),
                      style: HesabnaTypography.amountSmall(color: totalColor)
                          .copyWith(fontSize: 16)),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_left_rounded, color: context.cTextMuted),
                ],
              ),
              if (openingBalance != 0 || spent > 0 || paid > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (openingBalance != 0)
                        _Tag(
                          label: 'سابق: ${formatCurrency(openingBalance)}',
                          color: openingBalance > 0
                              ? HesabnaColors.lightDanger
                              : HesabnaColors.lightSuccess,
                        ),
                      if (spent > 0)
                        _Tag(
                          label: 'وجبات: ${formatCurrency(spent)}',
                          color: context.accentColor,
                        ),
                      if (paid > 0)
                        _Tag(
                          label: 'سداد: ${formatCurrency(paid)}',
                          color: HesabnaColors.lightSuccess,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.cBorder,
                    borderRadius: BorderRadius.circular(HesabnaRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.cAccentSoft,
                    child: Text(
                      name.isNotEmpty ? name[0] : '؟',
                      style: HesabnaTypography.subtitle(
                        color: context.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: HesabnaTypography.heading(color: context.cText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _MemberActionTile(
                icon: Icons.description_outlined,
                title: 'مشاركة الالتزامات PDF',
                subtitle: 'تصدير بيان العضو ومشاركته',
                color: context.accentColor,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSharePdf();
                },
              ),
              if (onPay != null) ...[
                const SizedBox(height: 10),
                _MemberActionTile(
                  icon: Icons.payments_outlined,
                  title: 'تسجيل سداد',
                  subtitle: 'إضافة سداد كامل أو جزئي',
                  color: HesabnaColors.lightSuccess,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onPay!();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MemberActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(HesabnaRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: context.isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(HesabnaRadius.md),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: HesabnaTypography.body(color: context.cText)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: HesabnaTypography.caption(color: context.cTextSub),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: context.cTextMuted),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final MemberModel member;
  final double remaining;

  const _PaymentSheet({required this.member, required this.remaining});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.remaining > 0 ? widget.remaining.toStringAsFixed(0) : '',
    );
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentNotifierProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تسجيل سداد',
                        style: HesabnaTypography.heading(color: context.cText)),
                    const SizedBox(height: 4),
                    Text(widget.member.name,
                        style:
                            HesabnaTypography.bodySm(color: context.cTextSub)),
                  ],
                ),
              ),
              Text(formatCurrency(widget.remaining),
                  style: HesabnaTypography.amountSmall(
                      color: HesabnaColors.lightDanger)),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: HesabnaTypography.amountSmall(color: context.cText),
            decoration: const InputDecoration(
              labelText: 'المبلغ المسدد',
              suffixText: saudiRiyalSymbol,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 3,
            style: HesabnaTypography.body(color: context.cText),
            decoration: const InputDecoration(
              labelText: 'ملاحظة اختيارية',
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!,
                style: HesabnaTypography.caption(
                    color: HesabnaColors.lightDanger)),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: state.isLoading ? null : _save,
            icon: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('حفظ السداد'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ السداد')),
      );
      return;
    }

    final ok = await ref.read(paymentNotifierProvider.notifier).addPayment(
          member: widget.member,
          amount: amount,
          note: _noteCtrl.text,
        );
    if (ok && mounted) Navigator.pop(context);
  }
}

class _EditPaymentSheet extends ConsumerStatefulWidget {
  final PaymentModel payment;

  const _EditPaymentSheet({required this.payment});

  @override
  ConsumerState<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends ConsumerState<_EditPaymentSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.payment.amount.toStringAsFixed(0),
    );
    _noteCtrl = TextEditingController(text: widget.payment.note);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentNotifierProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تعديل السداد',
                        style: HesabnaTypography.heading(color: context.cText)),
                    const SizedBox(height: 4),
                    Text(widget.payment.memberName,
                        style:
                            HesabnaTypography.bodySm(color: context.cTextSub)),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: context.accentColor),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: HesabnaTypography.amountSmall(color: context.cText),
            decoration: const InputDecoration(
              labelText: 'المبلغ المسدد',
              suffixText: saudiRiyalSymbol,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 3,
            style: HesabnaTypography.body(color: context.cText),
            decoration: const InputDecoration(
              labelText: 'ملاحظة اختيارية',
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!,
                style: HesabnaTypography.caption(
                    color: HesabnaColors.lightDanger)),
          ],
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: state.isLoading ? null : _save,
            icon: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغ السداد')),
      );
      return;
    }

    final ok = await ref.read(paymentNotifierProvider.notifier).updatePayment(
          widget.payment.copyWith(
            amount: amount,
            note: _noteCtrl.text.trim(),
          ),
        );
    if (ok && mounted) Navigator.pop(context);
  }
}

class _PaymentsSection extends StatelessWidget {
  final List<PaymentModel> payments;
  final void Function(PaymentModel payment) onEdit;
  final void Function(PaymentModel payment) onDelete;

  const _PaymentsSection({
    required this.payments,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final visiblePayments = payments.take(8).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        border: context.cardStyle == AppCardStyle.bordered
            ? Border.all(color: context.cBorder)
            : null,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: visiblePayments.asMap().entries.map((entry) {
          final i = entry.key;
          final payment = entry.value;
          return Column(
            children: [
              _PaymentHistoryRow(
                payment: payment,
                onEdit: () => onEdit(payment),
                onDelete: () => onDelete(payment),
              ),
              if (i < visiblePayments.length - 1)
                Divider(height: 1, indent: 16, color: context.cDivider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PaymentHistoryRow extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentHistoryRow({
    required this.payment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = _formatPaymentDate(payment.createdAt);

    return AppSwipeDelete(
      id: 'payment-${payment.id}',
      title: 'حذف السداد؟',
      message:
          '${formatCurrency(payment.amount)} من ${payment.memberName}. تقدر تتراجع بعد الحذف مباشرة.',
      onDelete: () async => onDelete(),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HesabnaColors.lightSuccess
                      .withValues(alpha: context.isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(HesabnaRadius.md),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: HesabnaColors.lightSuccess,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.memberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HesabnaTypography.subtitle(color: context.cText),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      payment.note.isEmpty ? date : '$date · ${payment.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          HesabnaTypography.caption(color: context.cTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(payment.amount),
                style: HesabnaTypography.amountSmall(
                        color: HesabnaColors.lightSuccess)
                    .copyWith(fontSize: 16),
              ),
              IconButton(
                tooltip: 'تعديل السداد',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_outlined,
                    color: context.cTextMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPaymentDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.length > 10 ? value.substring(0, 10) : value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════
//  TAG
// ═══════════════════════════════════════════

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(HesabnaRadius.xs),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: HesabnaTypography.caption(color: color)
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════
//  SHARED
// ═══════════════════════════════════════════
