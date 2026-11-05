import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/list_model.dart';
import '../../models/member_model.dart';
import '../../models/payment_model.dart';
import '../../models/record_model.dart';
import '../../providers/providers.dart';
import '../../widgets/app_widgets.dart';

final listStatsProvider =
    FutureProvider.autoDispose.family<ListStats, String>((ref, listId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final memberRepo = ref.watch(memberRepositoryProvider);
  final paymentRepo = ref.watch(paymentRepositoryProvider);
  final recordRepo = ref.watch(recordRepositoryProvider);
  final monthKey = DateTime.now().toIso8601String().substring(0, 7);
  final results = await Future.wait([
    memberRepo.getByListId(listId),
    recordRepo.getByListId(listId),
    paymentRepo.getByListId(listId),
  ]);
  final members = results[0] as List<MemberModel>;
  final records = results[1] as List<RecordModel>;
  final payments = results[2] as List<PaymentModel>;
  final monthRecords =
      records.where((r) => r.date.startsWith(monthKey)).toList();
  final monthPayments =
      payments.where((p) => p.createdAt.startsWith(monthKey)).toList();
  final monthExpenses =
      monthRecords.fold<double>(0, (sum, r) => sum + r.totalAmount);
  final monthPaid = monthPayments.fold<double>(0, (sum, p) => sum + p.amount);
  return ListStats(
    memberCount: members.length,
    recordCount: records.length,
    paymentCount: payments.length,
    monthExpenses: monthExpenses,
    monthPaid: monthPaid,
    lastActivity: records.isEmpty ? null : records.first.date,
  );
});

class ListStats {
  final int memberCount;
  final int recordCount;
  final int paymentCount;
  final double monthExpenses;
  final double monthPaid;
  final String? lastActivity;

  double get monthRemaining => monthExpenses - monthPaid;

  const ListStats({
    required this.memberCount,
    required this.recordCount,
    required this.paymentCount,
    required this.monthExpenses,
    required this.monthPaid,
    required this.lastActivity,
  });
}

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(listsProvider);

    return Scaffold(
      body: SafeArea(
        child: listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorCard(message: err.toString()),
          data: (lists) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              context.pagePad,
              18,
              context.pagePad,
              HesabnaSpacing.bottomNavPad + 32,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('القوائم',
                            style: HesabnaTypography.heading(
                                color: context.cText)),
                        Text('كل المجموعات والفرق في مكان واحد',
                            style: HesabnaTypography.caption(
                                color: context.cTextSub)),
                      ],
                    ),
                  ),
                  _CreateButton(
                      onTap: () => _showCreateListDialog(context, ref)),
                ],
              ),
              SizedBox(height: context.sectionGap),
              if (lists.isEmpty)
                _EmptyListsView(
                    onCreateTap: () => _showCreateListDialog(context, ref))
              else
                ...lists.map((list) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ListTileCard(list: list),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateListDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('قائمة جديدة'),
        content: TextField(
          controller: nameController,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'اسم القائمة',
            hintText: 'مثال: فطور المكتب',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('أدخل اسم القائمة')),
                );
                return;
              }
              final ok =
                  await ref.read(listNotifierProvider.notifier).createList(
                        name: name,
                        color: '#2563EB',
                      );
              if (!ok) {
                final error = ref.read(listNotifierProvider).error ??
                    'تعذر إنشاء القائمة';
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                }
                return;
              }
              ref.invalidate(listsProvider);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }
}

class _ListTileCard extends ConsumerWidget {
  final ListModel list;
  const _ListTileCard({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(listStatsProvider(list.id));

    return AppSwipeDelete(
      id: 'list-${list.id}',
      title: 'حذف القائمة؟',
      message:
          '"${list.name}" سيتم حذفها مع الأعضاء والوجبات والسدادات المرتبطة بها.',
      onDelete: () => _deleteList(context, ref),
      child: HesabnaCard(
        onTap: () => context.goToList(list.id),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.cAccentSoft,
                    borderRadius: BorderRadius.circular(HesabnaRadius.tile),
                  ),
                  child:
                      Icon(Icons.list_alt_outlined, color: context.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HesabnaTypography.title(color: context.cText),
                      ),
                      const SizedBox(height: 4),
                      stats.when(
                        loading: () => Text('جاري تحميل التفاصيل',
                            style: HesabnaTypography.caption(
                                color: context.cTextSub)),
                        error: (_, __) => Text('تعذر تحميل التفاصيل',
                            style: HesabnaTypography.caption(
                                color: context.cTextSub)),
                        data: (s) => Text(
                          '${s.memberCount} أعضاء · ${s.recordCount} وجبات · ${s.paymentCount} سدادات',
                          style: HesabnaTypography.caption(
                              color: context.cTextSub),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'خيارات القائمة',
                  onPressed: () => _showListOptions(context, ref),
                  icon:
                      Icon(Icons.more_horiz_rounded, color: context.cTextMuted),
                ),
              ],
            ),
            stats.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (s) => s.monthExpenses == 0 && s.monthPaid == 0
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _ListAmountChip(
                              label: 'مصاريف',
                              value: s.monthExpenses,
                              color: context.accentColor,
                            ),
                            const SizedBox(width: 8),
                            _ListAmountChip(
                              label: 'سداد',
                              value: s.monthPaid,
                              color: HesabnaColors.lightSuccess,
                            ),
                            const SizedBox(width: 8),
                            _ListAmountChip(
                              label: 'متبقي',
                              value: s.monthRemaining,
                              color: s.monthRemaining > 0
                                  ? HesabnaColors.lightDanger
                                  : s.monthRemaining < 0
                                      ? HesabnaColors.lightSuccess
                                      : context.cTextSub,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showListOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cBg,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(HesabnaRadius.full),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading:
                  Icon(Icons.list_alt_outlined, color: context.accentColor),
              title: Text(list.name,
                  style: HesabnaTypography.subtitle(color: context.cText)),
              subtitle: Text('خيارات القائمة',
                  style: HesabnaTypography.caption(color: context.cTextSub)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل الاسم'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showEditListDialog(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditListDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: list.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل اسم القائمة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'اسم القائمة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('أدخل اسم القائمة')),
                );
                return;
              }
              final ok = await ref
                  .read(listNotifierProvider.notifier)
                  .updateList(list.copyWith(name: name));
              if (!ok) {
                final error = ref.read(listNotifierProvider).error ??
                    'تعذر تعديل القائمة';
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                }
                return;
              }
              ref.invalidate(listStatsProvider(list.id));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteList(BuildContext context, WidgetRef ref) async {
    final deleted =
        await ref.read(listNotifierProvider.notifier).deleteList(list.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'تم حذف القائمة'
              : ref.read(listNotifierProvider).error ?? 'تعذر حذف القائمة',
        ),
      ),
    );
  }
}

class _ListAmountChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ListAmountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(HesabnaRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: HesabnaTypography.caption(color: context.cTextSub)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatCurrency(value),
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: HesabnaTypography.amountSmall(color: color)
                    .copyWith(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: const Icon(Icons.add),
    );
  }
}

class _EmptyListsView extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyListsView({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      padding: EdgeInsets.symmetric(horizontal: context.cardPad, vertical: 34),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.cHover,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.list_alt_outlined, color: context.cTextSub),
          ),
          const SizedBox(height: 18),
          Text('لا توجد قوائم بعد',
              style: HesabnaTypography.title(color: context.cText)),
          const SizedBox(height: 8),
          Text(
            'أنشئ قائمة للفريق، وبعدها أضف الأعضاء والوجبات.',
            textAlign: TextAlign.center,
            style: HesabnaTypography.bodySm(color: context.cTextSub),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء قائمة'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.pagePad),
        child: HesabnaCard(
          child: Text('تعذر تحميل القوائم: $message',
              style: HesabnaTypography.body(color: context.cText)),
        ),
      ),
    );
  }
}
