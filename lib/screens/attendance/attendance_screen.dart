// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/record_model.dart';
import '../../models/record_participant_model.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String listId;
  const AttendanceScreen({super.key, required this.listId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _totalCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _selectedDate = _todayStr();
  String? _selectedMealId;
  String _selectedMealName = '';
  double? _selectedMealDefaultPrice;
  double _totalAmount = 0;
  bool _amountEditedManually = false;
  Map<String, bool> _checked = {};

  static String _todayStr() =>
      DateTime.now().toIso8601String().split('T').first;

  int get _attendeeCount => _checked.values.where((v) => v).length;
  double get _perPerson => _attendeeCount > 0
      ? double.parse((_totalAmount / _attendeeCount).toStringAsFixed(2))
      : 0;

  @override
  void dispose() {
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider(widget.listId));
    final mealTypesAsync = ref.watch(mealTypesProvider(widget.listId));
    final notifier = ref.watch(recordNotifierProvider);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: const Text('تسجيل وجبة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goToList(widget.listId),
        ),
      ),
      body: membersAsync.when(
        loading: () => const AppLoadingView(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(membersProvider(widget.listId));
            ref.invalidate(mealTypesProvider(widget.listId));
          },
        ),
        data: (members) {
          if (_checked.length != members.length) {
            _checked = {
              for (final m in members)
                m.id: _checked[m.id] ?? m.isDefaultAttendee
            };
          }
          return ListView(
            padding: EdgeInsets.all(context.pagePad),
            children: [
              // ── التاريخ ──────────────────────────────────────────────
              _DateSelector(
                date: _selectedDate,
                onChanged: (d) => setState(() => _selectedDate = d),
              ),
              SizedBox(height: context.itemGap),

              // ── نوع الوجبة ───────────────────────────────────────────
              mealTypesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (meals) => meals.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel(text: 'نوع الوجبة'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: meals
                                .map((m) => _MealChip(
                                      label: m.name,
                                      selected: m.id == _selectedMealId,
                                      onTap: () => setState(() {
                                        _selectedMealId = m.id;
                                        _selectedMealName = m.name;
                                        _selectedMealDefaultPrice =
                                            m.defaultPrice;
                                        _amountEditedManually = false;
                                        _totalAmount =
                                            m.defaultPrice * _attendeeCount;
                                        _totalCtrl.text =
                                            _totalAmount.toStringAsFixed(0);
                                      }),
                                    ))
                                .toList(),
                          ),
                          SizedBox(height: context.itemGap),
                        ],
                      ),
              ),

              // ── المبلغ ───────────────────────────────────────────────
              const _FieldLabel(text: 'المبلغ الكلي للوجبة'),
              const SizedBox(height: 8),
              _AmountCard(
                controller: _totalCtrl,
                perPerson: _perPerson,
                count: _attendeeCount,
                onChanged: (v) => setState(() {
                  _amountEditedManually = true;
                  _totalAmount = v;
                }),
              ),
              SizedBox(height: context.itemGap),

              // ── الحاضرون ─────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: _FieldLabel(text: 'الحاضرون')),
                  Text(
                    '$_attendeeCount من ${members.length}',
                    style: HesabnaTypography.caption(color: context.cTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AttendanceActions(
                onSelectAll: () => _setAttendance(
                  {for (final m in members) m.id: true},
                ),
                onClear: () => _setAttendance(
                  {for (final m in members) m.id: false},
                ),
                onDefaults: () => _setAttendance(
                  {for (final m in members) m.id: m.isDefaultAttendee},
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                    color: context.cCard,
                    borderRadius: BorderRadius.circular(HesabnaRadius.lg),
                    border: context.cardStyle == AppCardStyle.bordered
                        ? Border.all(color: context.cBorder)
                        : null),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: members.asMap().entries.map((e) {
                    final i = e.key;
                    final m = e.value;
                    final checked = _checked[m.id] ?? false;
                    return Column(
                      children: [
                        _MemberRow(
                          name: m.name,
                          checked: checked,
                          share: checked ? _perPerson : null,
                          onTap: () => _toggleMember(m.id, checked),
                        ),
                        if (i < members.length - 1)
                          Divider(
                              height: 1, indent: 56, color: context.cDivider),
                      ],
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: context.itemGap),

              if (_attendeeCount > 0) ...[
                _SummaryBar(count: _attendeeCount, total: _totalAmount),
                SizedBox(height: context.itemGap),
              ],

              // ── ملاحظة ───────────────────────────────────────────────
              TextField(
                controller: _noteCtrl,
                textAlign: TextAlign.right,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'ملاحظة (اختياري)'),
              ),
              const SizedBox(height: 20),

              // ── حفظ ──────────────────────────────────────────────────
              _SaveButton(loading: notifier.isLoading, onPressed: _save),

              if (notifier.error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HesabnaColors.lightDanger
                        .withValues(alpha: context.isDark ? 0.18 : 0.10),
                  ),
                  child: Text(notifier.error!,
                      style: HesabnaTypography.bodySm(
                          color: HesabnaColors.lightDanger)),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_attendeeCount == 0) {
      _snack('اختر حاضراً واحداً على الأقل');
      return;
    }
    if (_totalAmount <= 0) {
      _snack('أدخل المبلغ الكلي للوجبة');
      return;
    }

    final record = RecordModel(
      id: const Uuid().v4(),
      listId: widget.listId,
      mealTypeId: _selectedMealId,
      mealName: _selectedMealName.isNotEmpty ? _selectedMealName : 'وجبة',
      date: _selectedDate,
      totalAmount: _totalAmount,
      perPerson: _perPerson,
      note: _noteCtrl.text.trim(),
    );

    final members = ref.read(membersProvider(widget.listId)).valueOrNull ?? [];
    final participants = members
        .where((m) => _checked[m.id] == true)
        .map((m) => RecordParticipantModel(
              id: const Uuid().v4(),
              recordId: record.id,
              memberId: m.id,
              memberName: m.name,
              share: _perPerson,
            ))
        .toList();

    final ok = await ref
        .read(recordNotifierProvider.notifier)
        .createRecord(record, participants);
    if (ok && mounted) {
      await _showSavedSheet(record, participants);
      if (mounted) context.goToList(widget.listId);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _toggleMember(String memberId, bool checked) {
    final next = Map<String, bool>.from(_checked)..[memberId] = !checked;
    _setAttendance(next);
  }

  void _setAttendance(Map<String, bool> next) {
    setState(() {
      _checked = next;
      _recalculateDefaultTotal();
    });
  }

  void _recalculateDefaultTotal() {
    final price = _selectedMealDefaultPrice;
    if (price == null || _amountEditedManually) return;
    _totalAmount = price * _attendeeCount;
    _totalCtrl.text = _totalAmount.toStringAsFixed(0);
  }

  Future<void> _showSavedSheet(
    RecordModel record,
    List<RecordParticipantModel> participants,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: HesabnaColors.lightSuccess
                          .withValues(alpha: context.isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(HesabnaRadius.md),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: HesabnaColors.lightSuccess),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('تم حفظ الوجبة',
                            style: HesabnaTypography.heading(
                                color: context.cText)),
                        const SizedBox(height: 4),
                        Text(
                          '${participants.length} حاضر · ${formatCurrency(record.totalAmount)}',
                          style: HesabnaTypography.caption(
                              color: context.cTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: _buildMealShareText(record, participants),
                      subject: 'وجبة ${record.mealName}',
                    ),
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('مشاركة مع المجموعة'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('تم'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMealShareText(
    RecordModel record,
    List<RecordParticipantModel> participants,
  ) {
    final names = participants.map((p) => p.memberName).join('، ');
    final note = record.note.isEmpty ? '' : '\nملاحظة: ${record.note}';
    return 'وجبة ${record.mealName} — ${record.date}\n'
        'الإجمالي: ${formatCurrency(record.totalAmount)}\n'
        'الحاضرون: ${participants.length}\n'
        'نصيب كل شخص: ${formatCurrency(record.perPerson, decimals: 2)}\n'
        'الأسماء: $names$note';
  }
}

// ═══════════════════════════════════════════
//  DATE SELECTOR
// ═══════════════════════════════════════════

class _DateSelector extends StatelessWidget {
  final String date;
  final void Function(String) onChanged;
  const _DateSelector({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.parse(date),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().split('T').first);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
            color: context.cCard,
            borderRadius: BorderRadius.circular(HesabnaRadius.lg),
            border: context.cardStyle == AppCardStyle.bordered
                ? Border.all(color: context.cBorder)
                : null),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: context.cTextSub),
            const SizedBox(width: 10),
            Expanded(
                child: Text(date,
                    style: HesabnaTypography.body(color: context.cText))),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: context.cTextMuted),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  MEAL CHIP
// ═══════════════════════════════════════════

class _MealChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MealChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.cAccentSoft : context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          border: Border.all(
              color: selected ? context.accentColor : context.cBorder),
        ),
        child: Text(
          label,
          style: HesabnaTypography.bodySm(
            color: selected ? context.accentColor : context.cTextSub,
          ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  AMOUNT CARD
// ═══════════════════════════════════════════

class _AmountCard extends StatelessWidget {
  final TextEditingController controller;
  final double perPerson;
  final int count;
  final void Function(double) onChanged;
  const _AmountCard(
      {required this.controller,
      required this.perPerson,
      required this.count,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: context.cardStyle == AppCardStyle.bordered
              ? Border.all(color: context.cBorder)
              : null),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: HesabnaTypography.amountLarge(color: context.cText),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: saudiRiyalSymbol,
              suffixStyle: HesabnaTypography.bodySm(color: context.cTextSub),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
          ),
          if (count > 0) ...[
            Divider(height: 20, color: context.cDivider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('نصيب كل شخص',
                    style: HesabnaTypography.bodySm(color: context.cText)),
                Text(formatCurrency(perPerson, decimals: 2),
                    style:
                        HesabnaTypography.subtitle(color: context.accentColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceActions extends StatelessWidget {
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onDefaults;

  const _AttendanceActions({
    required this.onSelectAll,
    required this.onClear,
    required this.onDefaults,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AttendanceActionButton(
            label: 'الكل',
            icon: Icons.done_all_rounded,
            onTap: onSelectAll,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AttendanceActionButton(
            label: 'إلغاء',
            icon: Icons.remove_done_rounded,
            onTap: onClear,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AttendanceActionButton(
            label: 'الافتراضي',
            icon: Icons.restart_alt_rounded,
            onTap: onDefaults,
          ),
        ),
      ],
    );
  }
}

class _AttendanceActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AttendanceActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HesabnaRadius.full),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: context.accentColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HesabnaTypography.caption(color: context.cTextSub)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  MEMBER ROW
// ═══════════════════════════════════════════

class _MemberRow extends StatelessWidget {
  final String name;
  final bool checked;
  final double? share;
  final VoidCallback onTap;
  const _MemberRow(
      {required this.name,
      required this.checked,
      required this.share,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selectedBg = context.cAccentSoft;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: checked ? selectedBg : Colors.transparent,
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: checked ? context.accentColor : context.cHover,
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(name.isNotEmpty ? name[0] : '؟',
                      style: HesabnaTypography.caption(color: context.cTextSub)
                          .copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name,
                  style: HesabnaTypography.body(color: context.cText).copyWith(
                    fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                    color: checked ? context.cText : context.cTextSub,
                  )),
            ),
            Text(
              share != null ? formatCurrency(share!, decimals: 2) : '—',
              style: HesabnaTypography.subtitle(
                color: checked ? context.accentColor : context.cTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SUMMARY BAR
// ═══════════════════════════════════════════

class _SummaryBar extends StatelessWidget {
  final int count;
  final double total;
  const _SummaryBar({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: context.cAccentSoft),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.people_outline, size: 16, color: context.accentColor),
            const SizedBox(width: 6),
            Text('$count حاضر',
                style: HesabnaTypography.bodySm(color: context.cText)),
          ]),
          Text(formatCurrency(total),
              style: HesabnaTypography.subtitle(color: context.accentColor)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SAVE BUTTON
// ═══════════════════════════════════════════

class _SaveButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _SaveButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        decoration: BoxDecoration(
          color: loading ? context.cHover : context.accentColor,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.cBg))
              : Text('حفظ السجل',
                  style: HesabnaTypography.subtitle(color: context.cBg)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SHARED
// ═══════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
      style: HesabnaTypography.bodySm(color: context.cText)
          .copyWith(fontWeight: FontWeight.w600));
}
