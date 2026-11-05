import 'package:flutter/material.dart';
import 'package:sticky_headers/sticky_headers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/record_model.dart';
import '../../models/record_participant_model.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

class RecordsScreen extends ConsumerStatefulWidget {
  final String listId;
  final String? highlightRecordId;
  final bool embedded;

  const RecordsScreen({
    super.key,
    required this.listId,
    this.highlightRecordId,
    this.embedded = false,
  });

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String _query = '';
  String? _filterMonth; // null = كل الشهور
  bool _showSearch = false;

  List<RecordModel> _filtered(List<RecordModel> all) {
    var list = all;
    if (_query.isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list
          .where(
              (r) => r.mealName.toLowerCase().contains(q) || r.date.contains(q))
          .toList();
    }
    if (_filterMonth != null) {
      list = list.where((r) => r.date.startsWith(_filterMonth!)).toList();
    }
    return list;
  }

  List<String> _months(List<RecordModel> all) {
    final set = <String>{};
    for (final r in all) {
      if (r.date.length < 7) continue;
      set.add(r.date.substring(0, 7));
    }
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(recordsProvider(widget.listId));

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: _showSearch
                  ? TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      style: HesabnaTypography.body(color: context.cText),
                      decoration: const InputDecoration(
                        hintText: 'بحث في السجلات...',
                        border: InputBorder.none,
                      ),
                    )
                  : const Text('السجل'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.goToList(widget.listId),
              ),
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
      body: recordsAsync.when(
        loading: () => AppLoadingView(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(recordsProvider(widget.listId)),
        ),
        data: (records) {
          final months = _months(records);
          final filtered = _filtered(records);

          return Column(
            children: [
              // ── Search bar (embedded فقط) ─────────────────────
              if (widget.embedded)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      context.pagePad, context.pagePad, context.pagePad, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: context.cHover,
                            borderRadius:
                                BorderRadius.circular(HesabnaRadius.md),
                            border: Border.all(color: context.cBorder),
                          ),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style:
                                HesabnaTypography.bodySm(color: context.cText),
                            decoration: InputDecoration(
                              hintText: 'بحث...',
                              hintStyle:
                                  HesabnaTypography.bodySm(color: context.cText)
                                      .copyWith(color: context.cTextMuted),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 16, color: context.cTextMuted),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Filter chips ──────────────────────────────────
              if (months.length > 1)
                _MonthFilter(
                  months: months,
                  selected: _filterMonth,
                  onSelect: (m) => setState(() => _filterMonth = m),
                ),

              // ── المحتوى ──────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? AppEmptyView(
                        icon: Icons.search_off_rounded,
                        label: 'لا توجد نتائج',
                        sub: _query.isNotEmpty
                            ? 'جرب كلمة بحث مختلفة'
                            : 'لا توجد سجلات لهذا الشهر',
                      )
                    : FadeInWidget(
                        child: _RecordsList(
                        records: filtered,
                        highlightRecordId: widget.highlightRecordId,
                        listId: widget.listId,
                        embedded: widget.embedded,
                      )),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Month Filter ──────────────────────────────────────────────────

class _MonthFilter extends StatelessWidget {
  final List<String> months;
  final String? selected;
  final void Function(String?) onSelect;

  const _MonthFilter({
    required this.months,
    required this.selected,
    required this.onSelect,
  });

  String _label(String key) {
    try {
      final p = key.split('-');
      final dt = DateTime(int.parse(p[0]), int.parse(p[1]));
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
      return '${names[dt.month]} ${dt.year}';
    } catch (_) {
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.pagePad, vertical: 6),
        children: [
          // الكل
          _Chip(
            label: 'الكل',
            active: selected == null,
            onTap: () => onSelect(null),
          ),
          ...months.map((m) => _Chip(
                label: _label(m),
                active: selected == m,
                onTap: () => onSelect(selected == m ? null : m),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScaleWrapper(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? context.accentColor : context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          border: Border.all(
            color: active ? context.accentColor : context.cBorder,
          ),
        ),
        child: Text(
          label,
          style: HesabnaTypography.caption(
            color: active ? context.cBg : context.cTextSub,
          ).copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w400),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  RECORDS LIST
// ═══════════════════════════════════════════

class _RecordsList extends ConsumerStatefulWidget {
  final List<RecordModel> records;
  final String? highlightRecordId;
  final String listId;
  final bool embedded;

  const _RecordsList({
    required this.records,
    required this.highlightRecordId,
    required this.listId,
    required this.embedded,
  });

  @override
  ConsumerState<_RecordsList> createState() => _RecordsListState();
}

class _RecordsListState extends ConsumerState<_RecordsList> {
  final _scrollController = ScrollController();

  Map<String, List<RecordModel>> get _grouped {
    final map = <String, List<RecordModel>>{};
    for (final r in widget.records) {
      final month = r.date.length >= 7 ? r.date.substring(0, 7) : 'غير مؤرخ';
      map.putIfAbsent(month, () => []).add(r);
    }
    return map;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final months = grouped.keys.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        context.pagePad,
        context.pagePad,
        context.pagePad,
        widget.embedded ? HesabnaSpacing.bottomNavPad : context.pagePad,
      ),
      itemCount: months.length,
      itemBuilder: (_, i) {
        final month = months[i];
        final records = grouped[month]!;
        return StickyHeader(
          header: Container(
            color: context.cBg,
            padding: EdgeInsets.only(
              bottom: 8,
              top: i == 0 ? 0 : 8,
            ),
            child: _MonthHeader(
                month: month,
                total: records.fold(0, (s, r) => s + r.totalAmount)),
          ),
          content: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                    color: context.cCard,
                    borderRadius: BorderRadius.circular(HesabnaRadius.lg),
                    border: context.cardStyle == AppCardStyle.bordered
                        ? Border.all(color: context.cBorder)
                        : null),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: records.asMap().entries.map((e) {
                    final idx = e.key;
                    final record = e.value;
                    return Column(
                      children: [
                        _RecordRow(
                          record: record,
                          highlight: record.id == widget.highlightRecordId,
                          onEdit: () => _editRecord(context, record),
                          onDelete: () => _deleteRecord(context, ref, record),
                          onTap: () => _showDetails(context, ref, record),
                        ),
                        if (idx < records.length - 1)
                          Divider(
                              height: 1, indent: 16, color: context.cDivider),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref, RecordModel record) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _RecordDetailsSheet(record: record),
    );
  }

  void _editRecord(BuildContext context, RecordModel record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cSurface,
      builder: (_) => _EditRecordSheet(
        record: record,
        listId: widget.listId,
        onSave: (updated, participants) async {
          await ref
              .read(recordNotifierProvider.notifier)
              .updateRecord(updated, participants);
        },
      ),
    );
  }

  Future<void> _deleteRecord(
      BuildContext context, WidgetRef ref, RecordModel record) async {
    final participants =
        await ref.read(recordRepositoryProvider).getParticipants(record.id);
    final deleted = await ref
        .read(recordNotifierProvider.notifier)
        .deleteRecord(record.id, widget.listId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleted
              ? 'تم حذف السجل'
              : ref.read(recordNotifierProvider).error ?? 'تعذر حذف السجل'),
          action: deleted
              ? SnackBarAction(
                  label: 'تراجع',
                  onPressed: () {
                    ref
                        .read(recordNotifierProvider.notifier)
                        .restoreRecord(record, participants);
                  },
                )
              : null,
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════
//  MONTH HEADER
// ═══════════════════════════════════════════

class _MonthHeader extends StatelessWidget {
  final String month;
  final double total;
  const _MonthHeader({required this.month, required this.total});

  String get _label {
    try {
      final p = month.split('-');
      final dt = DateTime(int.parse(p[0]), int.parse(p[1]));
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
      return '${names[dt.month]} ${dt.year}';
    } catch (_) {
      return month;
    }
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(_label,
              style: HesabnaTypography.bodySm(color: context.cText)
                  .copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: context.cHover,
              borderRadius: BorderRadius.circular(HesabnaRadius.full),
              border: Border.all(color: context.cBorder),
            ),
            child: Text(
              formatCurrency(total),
              style: HesabnaTypography.caption(color: context.cTextSub)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}

// ═══════════════════════════════════════════
//  RECORD ROW
// ═══════════════════════════════════════════

class _RecordRow extends StatelessWidget {
  final RecordModel record;
  final bool highlight;
  final VoidCallback onTap, onEdit, onDelete;

  const _RecordRow({
    required this.record,
    required this.highlight,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppSwipeDelete(
      id: 'record-${record.id}',
      title: 'حذف السجل؟',
      message:
          '"${record.mealName}" بتاريخ ${record.date}. تقدر تتراجع بعد الحذف مباشرة.',
      onDelete: () async => onDelete(),
      child: TapScaleWrapper(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: highlight ? context.cAccentSoft : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.cHover,
                      borderRadius: BorderRadius.circular(HesabnaRadius.sm),
                    ),
                    child: Icon(Icons.restaurant_outlined,
                        size: 16, color: context.cTextSub),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.mealName,
                            style: HesabnaTypography.subtitle(
                                color: context.cText)),
                        const SizedBox(height: 2),
                        Text(record.date,
                            style: HesabnaTypography.caption(
                                color: context.cTextMuted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCurrency(record.totalAmount),
                          style: HesabnaTypography.subtitle(
                              color: context.accentColor)),
                      const SizedBox(height: 2),
                      Text('${formatCurrency(record.perPerson)}/فرد',
                          style: HesabnaTypography.caption(
                              color: context.cTextMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ActionChip(
                    label: 'تعديل',
                    color: context.accentColor,
                    bg: context.cAccentSoft,
                    onTap: onEdit,
                  ),
                  if (record.note.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.notes_outlined,
                        size: 13, color: context.cTextMuted),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  ACTION CHIP
// ═══════════════════════════════════════════

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.label,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScaleWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(HesabnaRadius.xs),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: HesabnaTypography.caption(color: color)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  RECORD DETAILS SHEET
// ═══════════════════════════════════════════

class _RecordDetailsSheet extends ConsumerWidget {
  final RecordModel record;
  const _RecordDetailsSheet({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(participantsProvider(record.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(HesabnaRadius.full),
            ),
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.cHover,
                  borderRadius: BorderRadius.circular(HesabnaRadius.md),
                ),
                child: Icon(Icons.restaurant_outlined,
                    size: 18, color: context.cTextSub),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.mealName,
                        style: HesabnaTypography.heading(color: context.cText)),
                    Text(record.date,
                        style: HesabnaTypography.caption(
                            color: context.cTextMuted)),
                  ],
                ),
              ),
              Text(formatCurrency(record.totalAmount),
                  style: HesabnaTypography.amountSmall(
                      color: context.accentColor)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.cDivider),
          const SizedBox(height: 14),
          Text('المشاركون',
              style: HesabnaTypography.label(color: context.cTextSub)),
          const SizedBox(height: 10),
          participantsAsync.when(
            loading: () => AppLoadingView(rows: 2, card: false),
            error: (e, _) => AppErrorBanner(message: e.toString()),
            data: (participants) => Column(
              children: participants
                  .map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: context.cHover,
                              child: Text(
                                p.memberName.isNotEmpty ? p.memberName[0] : '؟',
                                style: HesabnaTypography.caption(
                                        color: context.cTextSub)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(p.memberName,
                                    style: HesabnaTypography.body(
                                        color: context.cText))),
                            Text(formatCurrency(p.share, decimals: 2),
                                style: HesabnaTypography.subtitle(
                                    color: context.accentColor)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (record.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: context.cDivider),
            const SizedBox(height: 12),
            Text('ملاحظة',
                style: HesabnaTypography.label(color: context.cTextSub)),
            const SizedBox(height: 4),
            Text(record.note,
                style: HesabnaTypography.body(color: context.cText)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  EMPTY + ERROR
// ═══════════════════════════════════════════
// ═══════════════════════════════════════════
//  EDIT RECORD SHEET
// ═══════════════════════════════════════════

class _EditRecordSheet extends ConsumerStatefulWidget {
  final RecordModel record;
  final String listId;
  final Future<void> Function(RecordModel, List<RecordParticipantModel>) onSave;

  const _EditRecordSheet({
    required this.record,
    required this.listId,
    required this.onSave,
  });

  @override
  ConsumerState<_EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends ConsumerState<_EditRecordSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _totalCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _dateCtrl;
  final Map<String, bool> _checked = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.record.mealName);
    _totalCtrl = TextEditingController(
        text: widget.record.totalAmount.toStringAsFixed(0));
    _noteCtrl = TextEditingController(text: widget.record.note);
    _dateCtrl = TextEditingController(text: widget.record.date);
  }

  // يتم تهيئة _checked مرة واحدة عند أول تحميل للمشاركين
  bool _participantsLoaded = false;

  void _initParticipants(List participants) {
    if (_participantsLoaded) return;
    _participantsLoaded = true;
    for (final p in participants) {
      if (p.memberId != null) _checked[p.memberId!] = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  double get _total => double.tryParse(_totalCtrl.text) ?? 0;
  int get _count => _checked.values.where((v) => v).length;
  double get _perPerson => _count > 0 ? _total / _count : 0;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _total <= 0) return;
    setState(() => _saving = true);

    final members = ref.read(membersProvider(widget.listId)).valueOrNull ?? [];

    final participants = members
        .where((m) => _checked[m.id] == true)
        .map((m) => RecordParticipantModel(
              id: const Uuid().v4(),
              recordId: widget.record.id,
              memberId: m.id,
              memberName: m.name,
              share: _perPerson,
            ))
        .toList();

    final updated = widget.record.copyWith(
      mealName: _nameCtrl.text.trim(),
      date: _dateCtrl.text.trim(),
      totalAmount: _total,
      perPerson: _perPerson,
      note: _noteCtrl.text.trim(),
    );

    await widget.onSave(updated, participants);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider(widget.listId));

    // تهيئة المشاركين المحددين عند أول تحميل
    ref.watch(participantsProvider(widget.record.id)).whenData(
          (participants) => _initParticipants(participants),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(HesabnaRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('تعديل السجل',
              style: HesabnaTypography.heading(color: context.cText)),
          const SizedBox(height: 16),

          // اسم الوجبة
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'اسم الوجبة',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HesabnaRadius.md)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // التاريخ + الإجمالي
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'التاريخ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HesabnaRadius.md)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _totalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'الإجمالي (ر)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HesabnaRadius.md)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // الأعضاء
          Text('الأعضاء',
              style: HesabnaTypography.label(color: context.cTextSub)),
          const SizedBox(height: 8),
          membersAsync.when(
            loading: () => AppLoadingView(rows: 2, card: false),
            error: (e, _) => AppErrorBanner(message: e.toString()),
            data: (members) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((m) {
                final checked = _checked[m.id] ?? false;
                return FilterChip(
                  label: Text(m.name),
                  selected: checked,
                  onSelected: (v) => setState(() => _checked[m.id] = v),
                );
              }).toList(),
            ),
          ),

          if (_count > 0) ...[
            const SizedBox(height: 8),
            Text(
              'نصيب كل فرد: ${formatCurrency(_perPerson, decimals: 1)}',
              style: HesabnaTypography.caption(color: context.cTextMuted),
            ),
          ],
          const SizedBox(height: 12),

          // ملاحظة
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HesabnaRadius.md)),
            ),
          ),
          const SizedBox(height: 20),

          // زر الحفظ
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.cBg),
                    )
                  : const Text('حفظ التعديلات'),
            ),
          ),
        ],
      ),
    );
  }
}
