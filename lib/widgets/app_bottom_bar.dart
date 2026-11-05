import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/hesabna_theme.dart';

// ════════════════════════════════════════════════════════════════════
//  APP BOTTOM BAR — الشريط السفلي الموحد لكل الشاشات
//
//  الاستخدام في HomeScreen / SettingsScreen:
//    bottomNavigationBar: AppBottomBar(activeScreen: ActiveScreen.home)
//
//  الاستخدام في ListShellScreen:
//    AppBottomBar(
//      activeScreen: ActiveScreen.list,
//      domeOpen:     _domeOpen,
//      onDomeTap:    _toggleDome,
//      onFabTap:     () => context.goToAttendance(listId),
//      showFab:      _currentIndex == 0 && !_domeOpen,
//    )
// ════════════════════════════════════════════════════════════════════

enum ActiveScreen { home, lists, list, settings }

class AppBottomBar extends StatelessWidget {
  final ActiveScreen activeScreen;

  // خاص بـ ListShellScreen فقط
  final bool domeOpen;
  final VoidCallback? onDomeTap;
  final VoidCallback? onFabTap;
  final bool showFab;

  final VoidCallback onHomeTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onManageTap;

  const AppBottomBar({
    super.key,
    required this.activeScreen,
    this.domeOpen = false,
    this.onDomeTap,
    this.onFabTap,
    this.showFab = false,
    required this.onHomeTap,
    required this.onSettingsTap,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: context.cSurface
                  .withValues(alpha: context.isDark ? 0.78 : 0.86),
              borderRadius: BorderRadius.circular(28),
              border:
                  Border.all(color: context.cBorder.withValues(alpha: 0.78)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isDark ? 0.34 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppNavItem(
                    icon: Icons.home_outlined,
                    active: activeScreen == ActiveScreen.home,
                    label: 'الرئيسية',
                    onTap: onHomeTap,
                  ),
                ),
                if (activeScreen == ActiveScreen.list && onDomeTap != null)
                  AppHubButton(open: domeOpen, onTap: onDomeTap!)
                else if (activeScreen == ActiveScreen.home)
                  AppHubButton(
                    open: false,
                    icon: Icons.list_alt_outlined,
                    label: 'القوائم',
                    onTap: onManageTap,
                  )
                else if (activeScreen == ActiveScreen.lists)
                  AppHubButton(
                    open: true,
                    icon: Icons.list_alt_outlined,
                    label: 'القوائم',
                    onTap: onManageTap,
                  )
                else if (activeScreen == ActiveScreen.settings)
                  AppHubButton(
                    open: false,
                    icon: Icons.list_alt_outlined,
                    label: 'القوائم',
                    onTap: onManageTap,
                  )
                else
                  AppHubButton(open: false, onTap: onManageTap),
                Expanded(
                  child: activeScreen == ActiveScreen.list &&
                          showFab &&
                          onFabTap != null
                      ? AppFabItem(onTap: onFabTap!)
                      : AppNavItem(
                          icon: Icons.settings_outlined,
                          active: activeScreen == ActiveScreen.settings,
                          label: 'الإعدادات',
                          onTap: onSettingsTap,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NAV ITEM
// ════════════════════════════════════════════════════════════════════

class AppNavItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;

  const AppNavItem({
    super.key,
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: active ? context.accentColor : context.cTextSub,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HesabnaTypography.caption(
              color: active ? context.accentColor : context.cTextSub,
            ).copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HUB BUTTON
// ════════════════════════════════════════════════════════════════════

class AppHubButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const AppHubButton({
    super.key,
    required this.open,
    required this.onTap,
    this.icon = Icons.apps_rounded,
    this.label = 'إدارة',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        open ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 126,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: open ? context.cText : context.cHover.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
          border: Border.all(
            color:
                open ? context.cText.withValues(alpha: 0.22) : context.cBorder,
          ),
          boxShadow: open
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: context.isDark ? 0.34 : 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                size: 18,
                color: open ? context.cBg : context.cTextSub,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HesabnaTypography.bodySm(
                  color: open ? context.cBg : context.cTextSub,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FAB ITEM
// ════════════════════════════════════════════════════════════════════

class AppFabItem extends StatelessWidget {
  final VoidCallback onTap;
  const AppFabItem({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.accentColor.withValues(alpha: 0.26),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(Icons.add, color: context.cBg, size: 20),
          ),
          const SizedBox(height: 3),
          Text(
            'وجبة',
            style: HesabnaTypography.caption(color: context.accentColor)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
