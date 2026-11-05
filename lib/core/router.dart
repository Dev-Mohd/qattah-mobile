import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/app_shell.dart';
import '../screens/about/about_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/lists/lists_screen.dart';
import '../screens/legal/legal_screen.dart';
import '../screens/list_shell/list_shell_screen.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/splash/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(
        location: state.uri.path,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/lists',
          builder: (context, state) => const ListsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/legal',
          builder: (context, state) => const LegalScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/list/:id',
      builder: (context, state) {
        final listId = state.pathParameters['id']!;
        return ListShellScreen(listId: listId, initialTab: 0);
      },
    ),
    GoRoute(
      path: '/list/:id/records',
      builder: (context, state) {
        final listId = state.pathParameters['id']!;
        return ListShellScreen(listId: listId, initialTab: 1);
      },
    ),
    GoRoute(
      path: '/list/:id/report',
      builder: (context, state) {
        final listId = state.pathParameters['id']!;
        return ListShellScreen(listId: listId, initialTab: 2);
      },
    ),
    GoRoute(
      path: '/list/:id/balances',
      builder: (context, state) {
        final listId = state.pathParameters['id']!;
        return ListShellScreen(listId: listId, initialTab: 3);
      },
    ),
    GoRoute(
      path: '/list/:id/attendance',
      builder: (context, state) {
        final listId = state.pathParameters['id']!;
        return AttendanceScreen(listId: listId);
      },
    ),
  ],
);

extension GoRouterExtension on BuildContext {
  void goToList(String listId) => go('/list/$listId');
  void goToAttendance(String listId) => go('/list/$listId/attendance');
  void goToRecords(String listId, {String? highlight}) =>
      go('/list/$listId/records');
  void goToReport(String listId) => go('/list/$listId/report');
  void goToSplash() => go('/splash');
  void goToHome() => go('/');
  void goToOnboarding() => go('/onboarding');
  void goToLists() => go('/lists');
  void goToSettings() => go('/settings');
  void goToLegal() => go('/legal');
  void goToAbout() => go('/about');
}
