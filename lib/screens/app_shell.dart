import 'package:flutter/material.dart';

import '../core/router.dart';
import '../widgets/app_bottom_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const AppShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final activeScreen = location.startsWith('/settings')
        ? ActiveScreen.settings
        : location.startsWith('/lists')
            ? ActiveScreen.lists
            : ActiveScreen.home;

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomBar(
        activeScreen: activeScreen,
        onHomeTap: context.goToHome,
        onSettingsTap: context.goToSettings,
        onManageTap: context.goToLists,
      ),
    );
  }
}
