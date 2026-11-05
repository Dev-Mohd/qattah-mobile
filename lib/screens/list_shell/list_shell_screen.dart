import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/app_bottom_bar.dart';
import '../../widgets/hub_dome.dart';
import '../balances/balances_screen.dart';
import '../list_detail/list_detail_screen.dart';
import '../records/records_screen.dart';
import '../report/report_screen.dart';

// ─── Tab definition ───────────────────────────────────────────────────────────

const _kTabs = [
  HubDomeItem(Icons.list_alt_outlined, 'القائمة'),
  HubDomeItem(Icons.history_outlined, 'السجل'),
  HubDomeItem(Icons.bar_chart_outlined, 'التقرير'),
  HubDomeItem(Icons.account_balance_wallet_outlined, 'الأرصدة'),
];

// ═══════════════════════════════════════════
//  LIST SHELL SCREEN
// ═══════════════════════════════════════════

class ListShellScreen extends ConsumerStatefulWidget {
  final String listId;
  final int initialTab;

  const ListShellScreen({
    super.key,
    required this.listId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<ListShellScreen> createState() => _ListShellScreenState();
}

class _ListShellScreenState extends ConsumerState<ListShellScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _domeOpen = false;
  late AnimationController _domeCtrl;
  late Animation<double> _domeAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _domeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _domeAnim = CurvedAnimation(
      parent: _domeCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _domeCtrl.dispose();
    super.dispose();
  }

  void _toggleDome() {
    setState(() => _domeOpen = !_domeOpen);
    _domeOpen ? _domeCtrl.forward() : _domeCtrl.reverse();
  }

  void _selectTab(int i) {
    setState(() {
      _currentIndex = i;
      _domeOpen = false;
    });
    _domeCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsProvider);
    final listName = listsAsync.whenData((lists) {
          for (final list in lists) {
            if (list.id == widget.listId) return list.name;
          }
          return 'القائمة';
        }).valueOrNull ??
        'القائمة';

    final screens = [
      ListDetailScreen(listId: widget.listId, embedded: true),
      RecordsScreen(listId: widget.listId, embedded: true),
      ReportScreen(listId: widget.listId, embedded: true),
      BalancesScreen(listId: widget.listId, embedded: true),
    ];

    return Scaffold(
      backgroundColor: context.cBg,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(listName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goToHome(),
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        activeScreen: ActiveScreen.list,
        domeOpen: _domeOpen,
        onDomeTap: _toggleDome,
        onFabTap: () => context.goToAttendance(widget.listId),
        showFab: _currentIndex == 0 && !_domeOpen,
        onHomeTap: context.goToHome,
        onSettingsTap: context.goToSettings,
        onManageTap: context.goToLists,
      ),
      body: Stack(
        children: [
          // ── الشاشة الحالية ─────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: screens[_currentIndex],
            ),
          ),

          // ── Backdrop ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: _domeAnim,
            builder: (_, __) {
              if (_domeAnim.value == 0) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _toggleDome,
                child: Container(
                  color: Colors.black.withValues(alpha: _domeAnim.value * 0.42),
                ),
              );
            },
          ),

          // ── Hub Dome ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _domeAnim,
              builder: (_, __) {
                if (_domeAnim.value == 0) return const SizedBox.shrink();
                return HesabnaHubDome(
                  animation: _domeAnim,
                  initialIndex: _currentIndex,
                  items: _kTabs,
                  onSelect: _selectTab,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
