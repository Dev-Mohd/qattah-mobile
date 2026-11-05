import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/currency.dart';
import '../../core/onboarding.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../models/member_model.dart';
import '../../models/payment_model.dart';
import '../../models/record_participant_model.dart';
import '../../models/record_model.dart';
import '../../providers/providers.dart';

final homeOverviewProvider =
    FutureProvider.autoDispose<HomeOverview>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));

  final lists = await ref.watch(listsProvider.future);
  final memberRepo = ref.watch(memberRepositoryProvider);
  final paymentRepo = ref.watch(paymentRepositoryProvider);
  final recordRepo = ref.watch(recordRepositoryProvider);

  var monthExpenseTotal = 0.0;
  var monthPaymentTotal = 0.0;
  var monthRecords = 0;
  var monthPayments = 0;
  var memberCount = 0;
  final activities = <HomeActivity>[];
  final debtLeaders = <HomeDebtItem>[];
  final monthKey = DateTime.now().toIso8601String().substring(0, 7);

  final snapshots = await Future.wait(lists.map((list) async {
    final results = await Future.wait([
      memberRepo.getByListId(list.id),
      recordRepo.getByListId(list.id),
      paymentRepo.getByListId(list.id),
      recordRepo.getAllParticipantsByListId(list.id),
    ]);
    return _HomeListSnapshot(
      listName: list.name,
      members: results[0] as List<MemberModel>,
      records: results[1] as List<RecordModel>,
      payments: results[2] as List<PaymentModel>,
      participants: results[3] as List<RecordParticipantModel>,
    );
  }));

  for (final snapshot in snapshots) {
    final members = snapshot.members;
    final records = snapshot.records;
    final payments = snapshot.payments;
    final participants = snapshot.participants;
    final monthListRecords =
        records.where((r) => r.date.startsWith(monthKey)).toList();
    final monthListPayments =
        payments.where((p) => p.createdAt.startsWith(monthKey)).toList();
    final listTotal =
        monthListRecords.fold<double>(0, (sum, r) => sum + r.totalAmount);
    final paymentTotal =
        monthListPayments.fold<double>(0, (sum, p) => sum + p.amount);

    memberCount += members.length;
    monthRecords += monthListRecords.length;
    monthPayments += monthListPayments.length;
    monthExpenseTotal += listTotal;
    monthPaymentTotal += paymentTotal;
    activities.addAll(records.take(2).map(HomeActivity.record));
    activities.addAll(payments.take(2).map(HomeActivity.payment));

    final spentMap = <String, double>{};
    final paidMap = <String, double>{};
    for (final participant in participants) {
      final key = (participant.memberId?.isNotEmpty ?? false)
          ? participant.memberId!
          : participant.memberName;
      spentMap[key] = (spentMap[key] ?? 0) + participant.share;
    }
    for (final payment in payments) {
      final memberId = payment.memberId;
      if (memberId == null) continue;
      paidMap[memberId] = (paidMap[memberId] ?? 0) + payment.amount;
    }
    HomeDebtItem? topDebtItem;
    for (final member in members) {
      final spent = (spentMap[member.id] ?? 0) + (spentMap[member.name] ?? 0);
      final paid = paidMap[member.id] ?? 0;
      final debt = member.openingBalance + spent - paid;
      if (debt > 0.005 && (topDebtItem == null || debt > topDebtItem.amount)) {
        topDebtItem = HomeDebtItem(
          memberName: member.name,
          listName: snapshot.listName,
          amount: debt,
        );
      }
    }
    if (topDebtItem != null) debtLeaders.add(topDebtItem);
  }

  activities.sort((a, b) => b.sortKey.compareTo(a.sortKey));
  debtLeaders.sort((a, b) => b.amount.compareTo(a.amount));
  final smartMessages = _buildSmartMessages(
    monthExpenseTotal: monthExpenseTotal,
    monthPaymentTotal: monthPaymentTotal,
    monthRecords: monthRecords,
    monthPayments: monthPayments,
    debtLeaders: debtLeaders,
  );

  return HomeOverview(
    listCount: lists.length,
    monthExpenseTotal: monthExpenseTotal,
    monthPaymentTotal: monthPaymentTotal,
    monthRecords: monthRecords,
    monthPayments: monthPayments,
    memberCount: memberCount,
    recentActivities: activities.take(5).toList(),
    debtLeaders: debtLeaders.take(5).toList(),
    smartMessages: smartMessages,
  );
});

List<HomeSmartMessage> _buildSmartMessages({
  required double monthExpenseTotal,
  required double monthPaymentTotal,
  required int monthRecords,
  required int monthPayments,
  required List<HomeDebtItem> debtLeaders,
}) {
  final messages = <HomeSmartMessage>[];
  final remaining = monthExpenseTotal - monthPaymentTotal;
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final daysLeft = lastDay - now.day;

  if (debtLeaders.isNotEmpty) {
    final top = debtLeaders.first;
    messages.add(HomeSmartMessage(
      title: 'تنبيه ذكي',
      body:
          '${top.memberName} هو الأعلى مديونية حاليًا في ${top.listName}: ${formatCurrency(top.amount)}.',
      tone: HomeSmartTone.warning,
    ));
  }

  if (remaining > 0.005 && daysLeft <= 5) {
    messages.add(HomeSmartMessage(
      title: 'نهاية الشهر قريبة',
      body:
          'باقي $daysLeft أيام تقريبًا، والمتبقي الحالي ${formatCurrency(remaining)}.',
      tone: HomeSmartTone.urgent,
    ));
  } else if (remaining > 0.005 && monthRecords > 0) {
    messages.add(HomeSmartMessage(
      title: 'متابعة السداد',
      body:
          'هذا الشهر فيه $monthRecords وجبة و$monthPayments سداد، والمتبقي ${formatCurrency(remaining)}.',
      tone: HomeSmartTone.warning,
    ));
  }

  if (monthExpenseTotal > 0 && monthPaymentTotal >= monthExpenseTotal) {
    messages.add(HomeSmartMessage(
      title: 'وضع ممتاز',
      body: 'السداد مغطي مصاريف الشهر بالكامل. القائمة ماشية بانضباط.',
      tone: HomeSmartTone.good,
    ));
  }

  if (messages.isEmpty) {
    messages.add(const HomeSmartMessage(
      title: 'جاهز للتسجيل',
      body: 'سجل أول وجبة هذا الشهر، وبعدها أعطيك تنبيهات أدق عن السداد.',
      tone: HomeSmartTone.neutral,
    ));
  }

  return messages.take(3).toList();
}

class _HomeListSnapshot {
  final String listName;
  final List<MemberModel> members;
  final List<RecordModel> records;
  final List<PaymentModel> payments;
  final List<RecordParticipantModel> participants;

  const _HomeListSnapshot({
    required this.listName,
    required this.members,
    required this.records,
    required this.payments,
    required this.participants,
  });
}

class HomeOverview {
  final int listCount;
  final double monthExpenseTotal;
  final double monthPaymentTotal;
  final int monthRecords;
  final int monthPayments;
  final int memberCount;
  final List<HomeActivity> recentActivities;
  final List<HomeDebtItem> debtLeaders;
  final List<HomeSmartMessage> smartMessages;

  double get monthNetTotal => monthExpenseTotal - monthPaymentTotal;

  const HomeOverview({
    required this.listCount,
    required this.monthExpenseTotal,
    required this.monthPaymentTotal,
    required this.monthRecords,
    required this.monthPayments,
    required this.memberCount,
    required this.recentActivities,
    required this.debtLeaders,
    required this.smartMessages,
  });
}

enum HomeSmartTone { neutral, good, warning, urgent }

class HomeSmartMessage {
  final String title;
  final String body;
  final HomeSmartTone tone;

  const HomeSmartMessage({
    required this.title,
    required this.body,
    required this.tone,
  });
}

class HomeDebtItem {
  final String memberName;
  final String listName;
  final double amount;

  const HomeDebtItem({
    required this.memberName,
    required this.listName,
    required this.amount,
  });
}

enum HomeActivityType { record, payment }

class HomeActivity {
  final HomeActivityType type;
  final RecordModel? record;
  final PaymentModel? payment;

  const HomeActivity._({
    required this.type,
    this.record,
    this.payment,
  });

  factory HomeActivity.record(RecordModel record) {
    return HomeActivity._(type: HomeActivityType.record, record: record);
  }

  factory HomeActivity.payment(PaymentModel payment) {
    return HomeActivity._(type: HomeActivityType.payment, payment: payment);
  }

  String get sortKey {
    switch (type) {
      case HomeActivityType.record:
        final value =
            record!.createdAt.isNotEmpty ? record!.createdAt : record!.date;
        return value;
      case HomeActivityType.payment:
        return payment!.createdAt;
    }
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _balanceKey = GlobalKey();
  final _smartKey = GlobalKey();
  final _debtKey = GlobalKey();
  final _activityKey = GlobalKey();
  bool _tourChecked = false;
  bool _showTour = false;

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(homeOverviewProvider);
    final creatorName = ref.watch(creatorNameValueProvider);
    final reminder = ref.watch(reminderProvider);
    final smartNotifications = ref.watch(smartNotificationsProvider);

    return Scaffold(
      body: overviewAsync.when(
        loading: () => const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => SafeArea(child: _HomeError(message: err.toString())),
        data: (overview) {
          _openHomeTourIfNeeded();
          final tourSteps = _buildTourSteps(
            smartEnabled:
                smartNotifications.enabled && overview.smartMessages.isNotEmpty,
            hasDebt: overview.debtLeaders.isNotEmpty,
          );

          return Stack(
            children: [
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        context.pagePad,
                        18,
                        context.pagePad,
                        HesabnaSpacing.bottomNavPad,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _GreetingHeader(
                            name: creatorName,
                            reminder: reminder,
                          ),
                          SizedBox(height: context.sectionGap),
                          KeyedSubtree(
                            key: _balanceKey,
                            child: _BalanceCard(overview: overview),
                          ),
                          const SizedBox(height: 12),
                          _StatsRow(overview: overview),
                          if (smartNotifications.enabled &&
                              overview.smartMessages.isNotEmpty) ...[
                            SizedBox(height: context.sectionGap),
                            KeyedSubtree(
                              key: _smartKey,
                              child: _SmartMessagesCard(
                                messages: overview.smartMessages,
                              ),
                            ),
                          ],
                          if (overview.debtLeaders.isNotEmpty) ...[
                            SizedBox(height: context.sectionGap),
                            KeyedSubtree(
                              key: _debtKey,
                              child: _DebtLeadersCard(
                                items: overview.debtLeaders,
                              ),
                            ),
                          ],
                          SizedBox(height: context.sectionGap),
                          KeyedSubtree(
                            key: _activityKey,
                            child: _SectionHeader(
                              title: 'آخر نشاط',
                              action: 'القوائم',
                              onAction: () => context.goToLists(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (overview.recentActivities.isEmpty)
                            _EmptyActivityView(
                              onCreateTap: () => context.goToLists(),
                            )
                          else
                            ...overview.recentActivities.map(
                              (activity) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ActivityTile(activity: activity),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_showTour)
                _HomeTourOverlay(
                  steps: tourSteps,
                  onFinish: _finishHomeTour,
                ),
            ],
          );
        },
      ),
      floatingActionButton: null,
    );
  }

  void _openHomeTourIfNeeded() {
    if (_tourChecked) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(homeTourSeenKey) ?? false;
      if (!mounted || seen) return;
      setState(() => _showTour = true);
    });
  }

  List<_HomeTourStep> _buildTourSteps({
    required bool smartEnabled,
    required bool hasDebt,
  }) {
    return [
      _HomeTourStep(
        keyRef: _balanceKey,
        title: 'ملخص الشهر',
        body: 'هنا تشوف المصاريف، السداد، والمتبقي لهذا الشهر في لقطة واحدة.',
      ),
      if (smartEnabled)
        _HomeTourStep(
          keyRef: _smartKey,
          title: 'التنبيهات الذكية',
          body:
              'هذه رسائل محلية تساعدك تلاحظ المتبقي، أعلى مديونية، وقرب نهاية الشهر.',
        ),
      if (hasDebt)
        _HomeTourStep(
          keyRef: _debtKey,
          title: 'أعلى مديونية',
          body:
              'يعرض أعلى شخص عليه مبلغ داخل كل قائمة حتى تعرف من يحتاج متابعة.',
        ),
      _HomeTourStep(
        keyRef: _activityKey,
        title: 'آخر نشاط',
        body:
            'هنا تظهر آخر الوجبات والسدادات. ومن زر القوائم تروح لإدارة القوائم والأعضاء.',
      ),
      const _HomeTourStep(
        title: 'ابدأ من القوائم',
        body:
            'استخدم زر القوائم في منتصف الشريط السفلي لإنشاء قائمة، ثم أضف الأعضاء وسجل أول وجبة.',
      ),
    ];
  }

  Future<void> _finishHomeTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(homeTourSeenKey, true);
    if (!mounted) return;
    setState(() => _showTour = false);
  }
}

class _GreetingHeader extends StatelessWidget {
  final String name;
  final ReminderSettings reminder;
  const _GreetingHeader({
    required this.name,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('السلام عليكم',
                  style: HesabnaTypography.caption(color: context.cTextSub)),
              const SizedBox(height: 2),
              Text(name,
                  style: HesabnaTypography.heading(color: context.cText)),
            ],
          ),
        ),
        _IconButton(
          icon: reminder.enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          active: reminder.enabled,
          onTap: () => _showReminderSheet(context),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 20,
          backgroundColor: context.cAccentSoft,
          child: Text(
            name.isEmpty ? 'ق' : name.characters.first,
            style: HesabnaTypography.subtitle(color: context.accentColor),
          ),
        ),
      ],
    );
  }

  void _showReminderSheet(BuildContext context) {
    final timeLabel = TimeOfDay(
      hour: reminder.hour,
      minute: reminder.minute,
    ).format(context);

    showModalBottomSheet(
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
                      color: reminder.enabled
                          ? context.cAccentSoft
                          : context.cHover,
                      borderRadius: BorderRadius.circular(HesabnaRadius.md),
                    ),
                    child: Icon(
                      reminder.enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                      color: reminder.enabled
                          ? context.accentColor
                          : context.cTextSub,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.enabled ? 'التذكير مفعل' : 'التذكير متوقف',
                          style:
                              HesabnaTypography.heading(color: context.cText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.enabled
                              ? 'سيصلك تذكير يومياً الساعة $timeLabel'
                              : 'فعّل التذكير اليومي من الإعدادات.',
                          style: HesabnaTypography.caption(
                              color: context.cTextSub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  context.goToSettings();
                },
                icon: const Icon(Icons.settings_outlined),
                label:
                    Text(reminder.enabled ? 'تعديل التذكير' : 'تفعيل التذكير'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTourStep {
  final GlobalKey? keyRef;
  final String title;
  final String body;

  const _HomeTourStep({
    this.keyRef,
    required this.title,
    required this.body,
  });
}

class _HomeTourOverlay extends StatefulWidget {
  final List<_HomeTourStep> steps;
  final Future<void> Function() onFinish;

  const _HomeTourOverlay({
    required this.steps,
    required this.onFinish,
  });

  @override
  State<_HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<_HomeTourOverlay> {
  int _index = 0;

  _HomeTourStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final target = _targetRect(_step.keyRef);
    final cardTop = _cardTop(context, target);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            CustomPaint(
              painter: _TourMaskPainter(
                target: target,
                color: Colors.black.withValues(alpha: 0.68),
              ),
              child: const SizedBox.expand(),
            ),
            if (target != null)
              Positioned.fromRect(
                rect: target.inflate(6),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(HesabnaRadius.xl),
                      border: Border.all(color: context.accentColor, width: 2),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: context.pagePad,
              right: context.pagePad,
              top: cardTop,
              child: _TourCard(
                step: _step,
                index: _index,
                count: widget.steps.length,
                isLast: _isLast,
                onSkip: widget.onFinish,
                onNext: () {
                  if (_isLast) {
                    widget.onFinish();
                  } else {
                    setState(() => _index++);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Rect? _targetRect(GlobalKey? key) {
    final context = key?.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  double _cardTop(BuildContext context, Rect? target) {
    final height = MediaQuery.sizeOf(context).height;
    const cardHeight = 210.0;
    if (target == null) return (height - cardHeight) / 2;
    final below = target.bottom + 18;
    if (below + cardHeight < height - 24) return below;
    return (target.top - cardHeight - 18).clamp(24.0, height - cardHeight - 24);
  }
}

class _TourCard extends StatelessWidget {
  final _HomeTourStep step;
  final int index;
  final int count;
  final bool isLast;
  final VoidCallback onNext;
  final Future<void> Function() onSkip;

  const _TourCard({
    required this.step,
    required this.index,
    required this.count,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.xl),
        border: Border.all(color: context.cBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.38 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.cAccentSoft,
                  borderRadius: BorderRadius.circular(HesabnaRadius.full),
                ),
                child: Text(
                  '${index + 1} من $count',
                  style: HesabnaTypography.caption(color: context.accentColor)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                child: const Text('تخطي'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: HesabnaTypography.heading(color: context.cText),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: HesabnaTypography.bodySm(color: context.cTextSub),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(isLast ? 'فهمت' : 'التالي'),
          ),
        ],
      ),
    );
  }
}

class _TourMaskPainter extends CustomPainter {
  final Rect? target;
  final Color color;

  const _TourMaskPainter({
    required this.target,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (target == null) {
      canvas.drawPath(full, Paint()..color = color);
      return;
    }

    final hole = RRect.fromRectAndRadius(
      target!.inflate(6),
      const Radius.circular(HesabnaRadius.xl),
    );
    final path = Path.combine(
      PathOperation.difference,
      full,
      Path()..addRRect(hole),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TourMaskPainter oldDelegate) {
    return oldDelegate.target != target || oldDelegate.color != color;
  }
}

class _BalanceCard extends StatelessWidget {
  final HomeOverview overview;
  const _BalanceCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('المتبقي هذا الشهر',
                  style: HesabnaTypography.caption(color: context.cTextSub)),
              const Spacer(),
              _StatusPill(
                  text:
                      '${overview.monthRecords} وجبة · ${overview.monthPayments} سداد'),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              formatCurrency(overview.monthNetTotal, decimals: 2),
              textDirection: TextDirection.ltr,
              style: HesabnaTypography.amountHero(
                color: overview.monthNetTotal > 0
                    ? HesabnaColors.lightDanger
                    : overview.monthNetTotal < 0
                        ? HesabnaColors.lightSuccess
                        : context.cText,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(saudiRiyalSymbol,
                style: HesabnaTypography.caption(color: context.cTextSub)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniAmount(
                  label: 'مصاريف',
                  value: overview.monthExpenseTotal,
                  color: context.accentColor),
              const SizedBox(width: 8),
              _MiniAmount(
                  label: 'سداد',
                  value: overview.monthPaymentTotal,
                  color: HesabnaColors.lightSuccess),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final HomeOverview overview;
  const _StatsRow({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatTile(label: 'قوائم', value: '${overview.listCount}')),
        const SizedBox(width: 8),
        Expanded(
            child: _StatTile(label: 'أعضاء', value: '${overview.memberCount}')),
        const SizedBox(width: 8),
        Expanded(
            child:
                _StatTile(label: 'سدادات', value: '${overview.monthPayments}')),
      ],
    );
  }
}

class _SmartMessagesCard extends StatelessWidget {
  final List<HomeSmartMessage> messages;
  const _SmartMessagesCard({required this.messages});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.cAccentSoft,
                  borderRadius: BorderRadius.circular(HesabnaRadius.md),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: context.accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تنبيهات ذكية',
                        style:
                            HesabnaTypography.subtitle(color: context.cText)),
                    const SizedBox(height: 2),
                    Text('مولدة محليًا من بيانات التطبيق',
                        style:
                            HesabnaTypography.caption(color: context.cTextSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...messages.asMap().entries.map((entry) {
            final i = entry.key;
            final message = entry.value;
            return Padding(
              padding:
                  EdgeInsets.only(bottom: i == messages.length - 1 ? 0 : 8),
              child: _SmartMessageTile(message: message),
            );
          }),
        ],
      ),
    );
  }
}

class _SmartMessageTile extends StatelessWidget {
  final HomeSmartMessage message;
  const _SmartMessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final color = switch (message.tone) {
      HomeSmartTone.good => HesabnaColors.lightSuccess,
      HomeSmartTone.warning => context.accentColor,
      HomeSmartTone.urgent => HesabnaColors.lightDanger,
      HomeSmartTone.neutral => context.cTextSub,
    };
    final icon = switch (message.tone) {
      HomeSmartTone.good => Icons.check_circle_outline_rounded,
      HomeSmartTone.warning => Icons.lightbulb_outline_rounded,
      HomeSmartTone.urgent => Icons.priority_high_rounded,
      HomeSmartTone.neutral => Icons.tips_and_updates_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(HesabnaRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: HesabnaTypography.body(color: context.cText)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  message.body,
                  style: HesabnaTypography.caption(color: context.cTextSub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtLeadersCard extends StatelessWidget {
  final List<HomeDebtItem> items;
  const _DebtLeadersCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxAmount = items.fold<double>(
      0,
      (max, item) => item.amount > max ? item.amount : max,
    );

    return HesabnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: HesabnaColors.lightDanger
                      .withValues(alpha: context.isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(HesabnaRadius.md),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: HesabnaColors.lightDanger,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أكثر مديونية',
                        style:
                            HesabnaTypography.subtitle(color: context.cText)),
                    const SizedBox(height: 2),
                    Text('أعلى عضو مديونية داخل كل قائمة',
                        style:
                            HesabnaTypography.caption(color: context.cTextSub)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            final progress = maxAmount == 0 ? 0.0 : item.amount / maxAmount;
            return Padding(
              padding: EdgeInsets.only(bottom: rank == items.length ? 0 : 12),
              child: _DebtBarRow(
                rank: rank,
                item: item,
                progress: progress.clamp(0.06, 1.0),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DebtBarRow extends StatelessWidget {
  final int rank;
  final HomeDebtItem item;
  final double progress;

  const _DebtBarRow({
    required this.rank,
    required this.item,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cHover,
                borderRadius: BorderRadius.circular(HesabnaRadius.sm),
              ),
              child: Text(
                '$rank',
                style: HesabnaTypography.caption(color: context.cTextSub)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HesabnaTypography.body(color: context.cText)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    item.listName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HesabnaTypography.caption(color: context.cTextMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatCurrency(item.amount),
              textDirection: TextDirection.ltr,
              style: HesabnaTypography.amountSmall(
                      color: HesabnaColors.lightDanger)
                  .copyWith(fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: context.cHover,
            valueColor:
                const AlwaysStoppedAnimation<Color>(HesabnaColors.lightDanger),
          ),
        ),
      ],
    );
  }
}

class _MiniAmount extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniAmount({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(HesabnaRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: HesabnaTypography.caption(color: context.cTextSub))),
            Text(
              formatCurrency(value),
              textDirection: TextDirection.ltr,
              style: HesabnaTypography.label(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: HesabnaTypography.caption(color: context.cTextSub)),
          const SizedBox(height: 4),
          Text(value, style: HesabnaTypography.title(color: context.cText)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: HesabnaTypography.subtitle(color: context.cText)),
        const Spacer(),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(action!),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final HomeActivity activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final isPayment = activity.type == HomeActivityType.payment;
    final record = activity.record;
    final payment = activity.payment;
    final title = isPayment ? 'سداد ${payment!.memberName}' : record!.mealName;
    final subtitle = isPayment ? _dateOnly(payment!.createdAt) : record!.date;
    final amount = isPayment ? payment!.amount : record!.totalAmount;
    final icon = isPayment ? Icons.payments_outlined : Icons.receipt_long;
    final color = isPayment ? HesabnaColors.lightSuccess : context.accentColor;

    return Container(
      constraints: BoxConstraints(minHeight: context.rowHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.tile),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                color.withValues(alpha: context.isDark ? 0.18 : 0.10),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: HesabnaTypography.subtitle(color: context.cText)),
                Text(subtitle,
                    style: HesabnaTypography.caption(color: context.cTextSub)),
              ],
            ),
          ),
          Text(
            '${isPayment ? '-' : ''}${amount.toStringAsFixed(0)}',
            textDirection: TextDirection.ltr,
            style: HesabnaTypography.amountSmall(color: color),
          ),
        ],
      ),
    );
  }

  String _dateOnly(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value.length > 10 ? value.substring(0, 10) : value;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyActivityView extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyActivityView({required this.onCreateTap});

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
            child: Icon(Icons.local_cafe_outlined, color: context.cTextSub),
          ),
          const SizedBox(height: 18),
          Text('لا توجد أنشطة بعد',
              style: HesabnaTypography.title(color: context.cText)),
          const SizedBox(height: 8),
          Text(
            'افتح صفحة القوائم، أضف أعضاءك، ثم سجل أول وجبة.',
            textAlign: TextAlign.center,
            style: HesabnaTypography.bodySm(color: context.cTextSub),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add),
            label: const Text('فتح القوائم'),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  const _HomeError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.pagePad),
        child: HesabnaCard(
          child: Text('تعذر تحميل الصفحة: $message',
              style: HesabnaTypography.body(color: context.cText)),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _IconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HesabnaRadius.md),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(HesabnaRadius.md),
          border:
              Border.all(color: active ? context.accentColor : context.cBorder),
        ),
        child: Icon(icon,
            size: 20, color: active ? context.accentColor : context.cText),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.cAccentSoft,
        borderRadius: BorderRadius.circular(HesabnaRadius.full),
      ),
      child: Text(text,
          style: HesabnaTypography.label(color: context.accentColor)),
    );
  }
}
