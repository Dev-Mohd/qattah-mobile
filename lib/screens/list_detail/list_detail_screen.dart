import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/meal_type_model.dart';
import '../../models/member_model.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

class ListDetailScreen extends ConsumerWidget {
  final String listId;
  final bool embedded;
  const ListDetailScreen(
      {super.key, required this.listId, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsProvider);
    final membersAsync = ref.watch(membersProvider(listId));
    final mealsAsync = ref.watch(mealTypesProvider(listId));

    final listName = listsAsync.whenData((lists) {
          for (final list in lists) {
            if (list.id == listId) return list.name;
          }
          return 'القائمة';
        }).valueOrNull ??
        'القائمة';

    final body = FadeInWidget(
        child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.pagePad,
            context.pagePad,
            context.pagePad,
            embedded ? HesabnaSpacing.bottomNavPad : context.pagePad,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── الأعضاء ─────────────────────────────────────────────
              _SectionHeader(
                title: 'الأعضاء',
                action: 'إضافة',
                onAction: () => _showAddMemberSheet(context, ref),
              ),
              const SizedBox(height: 10),
              membersAsync.when(
                loading: () => const _LoadingPlaceholder(),
                error: (e, _) => _ErrorBanner(message: e.toString()),
                data: (members) => members.isEmpty
                    ? _EmptyState(
                        label: 'لا يوجد أعضاء بعد',
                        sub: 'اضغط "إضافة" لإضافة أول عضو',
                        onTap: () => _showAddMemberSheet(context, ref),
                      )
                    : _MembersScroller(
                        members: members,
                        onEdit: (m) => _showAddMemberSheet(context, ref, m),
                        onDelete: (id) async {
                          await ref
                              .read(memberNotifierProvider.notifier)
                              .deleteMember(id: id, listId: listId);
                        },
                      ),
              ),

              SizedBox(height: context.sectionGap),

              // ── الوجبات ──────────────────────────────────────────────
              _SectionHeader(
                title: 'الوجبات',
                action: 'إضافة',
                onAction: () => _showAddMealSheet(context, ref),
              ),
              const SizedBox(height: 10),
              mealsAsync.when(
                loading: () => const _LoadingPlaceholder(),
                error: (e, _) => _ErrorBanner(message: e.toString()),
                data: (meals) => meals.isEmpty
                    ? _EmptyState(
                        label: 'لا توجد وجبات بعد',
                        sub: 'اضغط "إضافة" لإضافة نوع وجبة',
                        onTap: () => _showAddMealSheet(context, ref),
                      )
                    : _MealsList(
                        meals: meals,
                        onEdit: (m) => _showAddMealSheet(context, ref, m),
                        onDelete: (id) async {
                          await ref
                              .read(mealTypeNotifierProvider.notifier)
                              .deleteMealType(id: id, listId: listId);
                        },
                      ),
              ),

              SizedBox(height: context.sectionGap),

              if (!embedded) ...[
                membersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) => members.isEmpty
                      ? _NoMembersWarning()
                      : _PrimaryButton(
                          label: 'تسجيل وجبة اليوم',
                          icon: Icons.add_circle_outline,
                          onTap: () => context.goToAttendance(listId),
                        ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _SecondaryButton(
                    label: 'السجل',
                    icon: Icons.history_outlined,
                    onTap: () => context.goToRecords(listId),
                  )),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SecondaryButton(
                    label: 'التقرير',
                    icon: Icons.bar_chart_outlined,
                    onTap: () => context.goToReport(listId),
                  )),
                ]),
              ] else
                membersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (members) => members.isEmpty
                      ? _NoMembersWarning()
                      : const SizedBox.shrink(),
                ),
            ]),
          ),
        ),
      ],
    ));

    if (embedded) return body;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: Text(listName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.goToHome(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _showListOptions(context, ref),
          ),
        ],
      ),
      floatingActionButton: membersAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => context.goToAttendance(listId),
              label: Text('+ تسجيل وجبة',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: context.cBg)),
              backgroundColor: context.cText,
              elevation: 0,
            )
          : null,
      body: body,
    );
  }

  void _showAddMemberSheet(BuildContext context, WidgetRef ref,
      [MemberModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMemberSheet(
        existing: existing,
        onSave: (name, balance, isDefaultAttendee) async {
          if (existing != null) {
            final ok = await ref
                .read(memberNotifierProvider.notifier)
                .updateMember(existing.copyWith(
                  name: name,
                  openingBalance: balance,
                  isDefaultAttendee: isDefaultAttendee,
                ));
            if (!ok && context.mounted) {
              _showSaveError(context, ref.read(memberNotifierProvider).error);
            }
            return ok;
          } else {
            final ok =
                await ref.read(memberNotifierProvider.notifier).addMember(
                      listId: listId,
                      name: name,
                      openingBalance: balance,
                      isDefaultAttendee: isDefaultAttendee,
                    );
            if (!ok && context.mounted) {
              _showSaveError(context, ref.read(memberNotifierProvider).error);
            }
            return ok;
          }
        },
      ),
    );
  }

  void _showAddMealSheet(BuildContext context, WidgetRef ref,
      [MealTypeModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMealSheet(
        existing: existing,
        onSave: (name, price) async {
          if (existing != null) {
            final ok = await ref
                .read(mealTypeNotifierProvider.notifier)
                .updateMealType(
                    existing.copyWith(name: name, defaultPrice: price));
            if (!ok && context.mounted) {
              _showSaveError(context, ref.read(mealTypeNotifierProvider).error);
            }
            return ok;
          } else {
            final ok = await ref
                .read(mealTypeNotifierProvider.notifier)
                .addMealType(listId: listId, name: name, defaultPrice: price);
            if (!ok && context.mounted) {
              _showSaveError(context, ref.read(mealTypeNotifierProvider).error);
            }
            return ok;
          }
        },
      ),
    );
  }

  void _showSaveError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'تعذر حفظ التغييرات')),
    );
  }

  void _showListOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('السجل الكامل'),
              onTap: () {
                Navigator.pop(context);
                context.goToRecords(listId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('التقرير الشهري'),
              onTap: () {
                Navigator.pop(context);
                context.goToReport(listId);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  SECTION HEADER
// ═══════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title, action;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: HesabnaTypography.heading(color: context.cText))),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.cHover,
              borderRadius: BorderRadius.circular(HesabnaRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 14, color: context.accentColor),
                const SizedBox(width: 4),
                Text(action,
                    style: HesabnaTypography.caption(color: context.accentColor)
                        .copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
//  MEMBERS SCROLLER — avatars أفقية
// ═══════════════════════════════════════════

class _MembersScroller extends StatelessWidget {
  final List<MemberModel> members;
  final void Function(MemberModel) onEdit;
  final void Function(String) onDelete;
  const _MembersScroller({
    required this.members,
    required this.onEdit,
    required this.onDelete,
  });

  // ألوان الأفاتار
  static const _avatarColors = [
    Color(0xFFE8D5F5),
    Color(0xFFD5E8F5),
    Color(0xFFD5F5E8),
    Color(0xFFF5E8D5),
    Color(0xFFF5D5D5),
    Color(0xFFD5D5F5),
    Color(0xFFF5F5D5),
    Color(0xFFD5F5F5),
  ];
  static const _avatarTextColors = [
    Color(0xFF7C3AED),
    Color(0xFF1D6FA4),
    Color(0xFF15803D),
    Color(0xFFC2750C),
    Color(0xFFB91C1C),
    Color(0xFF4338CA),
    Color(0xFF92400E),
    Color(0xFF0E7490),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final m = members[i];
          final ci = i % _avatarColors.length;
          final bg = _avatarColors[ci];
          final fg = _avatarTextColors[ci];
          final initial = m.name.isNotEmpty ? m.name[0] : '؟';

          return TapScaleWrapper(
            onTap: () => _showOptions(context, m),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 76,
                  child: Text(
                    m.name.split(' ').first,
                    style: HesabnaTypography.caption(color: context.cText)
                        .copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOptions(BuildContext context, MemberModel m) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(m.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: m.openingBalance != 0
                  ? Text(
                      'رصيد سابق: ${formatCurrency(m.openingBalance)} · ${m.isDefaultAttendee ? 'حاضر افتراضياً' : 'غير حاضر افتراضياً'}',
                    )
                  : Text(m.isDefaultAttendee
                      ? 'حاضر افتراضياً'
                      : 'غير حاضر افتراضياً'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(context);
                onEdit(m);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('حذف',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, m.name, () => onDelete(m.id));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, String name, VoidCallback onConfirm) async {
    final ok = await showAppConfirmSheet(
      ctx,
      title: 'حذف عضو؟',
      message: 'سيتم حذف "$name" من القائمة.',
    );
    if (ok) onConfirm();
  }
}

// ═══════════════════════════════════════════
//  MEALS LIST
// ═══════════════════════════════════════════

class _MealsList extends StatelessWidget {
  final List<MealTypeModel> meals;
  final void Function(MealTypeModel) onEdit;
  final void Function(String) onDelete;
  const _MealsList(
      {required this.meals, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: meals
          .map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppSwipeDelete(
                  id: 'meal-${m.id}',
                  title: 'حذف نوع الوجبة؟',
                  message: 'سيتم حذف "${m.name}" من أنواع الوجبات.',
                  onDelete: () async => onDelete(m.id),
                  child: TapScaleWrapper(
                    onTap: () => onEdit(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                          color: context.cCard,
                          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
                          border: context.cardStyle == AppCardStyle.bordered
                              ? Border.all(color: context.cBorder)
                              : null),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.cHover,
                            borderRadius:
                                BorderRadius.circular(HesabnaRadius.sm),
                          ),
                          child: Icon(Icons.dining_outlined,
                              size: 20, color: context.cTextSub),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name,
                                  style: HesabnaTypography.subtitle(
                                          color: context.cText)
                                      .copyWith(fontWeight: FontWeight.w700)),
                              Text('للوجبة',
                                  style: HesabnaTypography.caption(
                                      color: context.cTextMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              m.defaultPrice.toStringAsFixed(2),
                              style: HesabnaTypography.amountSmall(
                                      color: context.cText)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text('للوجبة',
                                style: HesabnaTypography.caption(
                                    color: context.cTextMuted)),
                          ],
                        ),
                      ]),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String label, sub;
  final VoidCallback onTap;
  const _EmptyState(
      {required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline, size: 32, color: context.cTextMuted),
            const SizedBox(height: 8),
            Text(label,
                style: HesabnaTypography.subtitle(color: context.cText)
                    .copyWith(color: context.cTextSub)),
            const SizedBox(height: 4),
            Text(sub,
                style: HesabnaTypography.caption(color: context.cTextMuted)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  PRIMARY & SECONDARY BUTTONS
// ═══════════════════════════════════════════

// ignore_for_file: prefer_const_constructors
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScaleWrapper(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: context.accentColor,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.cBg, size: 18),
            const SizedBox(width: 8),
            Text(label, style: HesabnaTypography.subtitle(color: context.cBg)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScaleWrapper(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.cTextSub, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: HesabnaTypography.bodySm(color: context.cText)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  ADD MEMBER SHEET
// ═══════════════════════════════════════════

class _AddMemberSheet extends StatefulWidget {
  final MemberModel? existing;
  final Future<bool> Function(String, double, bool) onSave;
  const _AddMemberSheet({this.existing, required this.onSave});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late bool _isDefaultAttendee;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: widget.existing != null && widget.existing!.openingBalance != 0
          ? widget.existing!.openingBalance.toStringAsFixed(0)
          : '',
    );
    _isDefaultAttendee = widget.existing?.isDefaultAttendee ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Text(isEdit ? 'تعديل العضو' : 'إضافة عضو',
              style: HesabnaTypography.heading(color: context.cText)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(hintText: 'اسم العضو'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'رصيد سابق (دين قديم)',
              hintText: '0',
              suffixText: saudiRiyalSymbol,
              helperText: 'اتركه فارغاً إن لم يوجد دين سابق',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.cHover,
              borderRadius: BorderRadius.circular(HesabnaRadius.md),
              border: Border.all(color: context.cBorder),
            ),
            child: SwitchListTile.adaptive(
              value: _isDefaultAttendee,
              onChanged: (value) => setState(() => _isDefaultAttendee = value),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: context.accentColor,
              title: Text(
                'حاضر افتراضياً',
                style: HesabnaTypography.subtitle(color: context.cText),
              ),
              subtitle: Text(
                'يتم تحديده تلقائيًا عند تسجيل وجبة جديدة',
                style: HesabnaTypography.caption(color: context.cTextMuted),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.cBg))
                  : Text(isEdit ? 'حفظ التعديل' : 'إضافة'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم العضو')),
      );
      return;
    }
    if (balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرصيد السابق لا يمكن أن يكون سالبًا')),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await widget.onSave(name, balance, _isDefaultAttendee);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════
//  ADD MEAL SHEET
// ═══════════════════════════════════════════

class _AddMealSheet extends StatefulWidget {
  final MealTypeModel? existing;
  final Future<bool> Function(String, double) onSave;
  const _AddMealSheet({this.existing, required this.onSave});

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _priceCtrl = TextEditingController(
      text: widget.existing != null
          ? widget.existing!.defaultPrice.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          Text(isEdit ? 'تعديل الوجبة' : 'إضافة وجبة',
              style: HesabnaTypography.heading(color: context.cText)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
                hintText: 'اسم الوجبة (مثال: فطور الصباح)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'السعر الافتراضي للفرد',
              suffixText: saudiRiyalSymbol,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.cBg))
                  : Text(isEdit ? 'حفظ التعديل' : 'إضافة'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم الوجبة')),
      );
      return;
    }
    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السعر لا يمكن أن يكون سالبًا')),
      );
      return;
    }
    setState(() => _loading = true);
    final ok = await widget.onSave(name, price);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.cBorder,
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: context.cHover,
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HesabnaColors.lightDanger
              .withValues(alpha: context.isDark ? 0.18 : 0.10),
        ),
        child: Text(message,
            style: HesabnaTypography.bodySm(color: HesabnaColors.lightDanger)),
      );
}

class _NoMembersWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.cAccentSoft),
        child: Row(children: [
          Icon(Icons.info_outline, color: context.accentColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أضف عضواً واحداً على الأقل لتسجيل الحضور',
              style: HesabnaTypography.bodySm(color: context.accentColor),
            ),
          ),
        ]),
      );
}
