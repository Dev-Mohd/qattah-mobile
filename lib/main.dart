import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notification_service.dart';
import 'core/router.dart';
import 'core/theme/hesabna_theme.dart';
import 'providers/appearance_providers.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotificationService().init();

  runApp(const ProviderScope(child: QattahApp()));
}

class QattahApp extends ConsumerWidget {
  const QattahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeValueProvider);
    final accentColor = ref.watch(accentColorValueProvider);
    final density = ref.watch(densityValueProvider);
    final cardStyle = ref.watch(cardStyleValueProvider);

    return HesabnaAppearance(
      accent: accentColor,
      density: density,
      cardStyle: cardStyle,
      child: Builder(
        builder: (context) {
          final theme = HesabnaTheme.buildTheme(
            context: context,
            brightness: Brightness.light,
            accent: accentColor,
          );
          final darkTheme = HesabnaTheme.buildTheme(
            context: context,
            brightness: Brightness.dark,
            accent: accentColor,
          );

          return MaterialApp.router(
            title: 'قطه',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: theme,
            darkTheme: darkTheme,
            routerConfig: router,
            locale: const Locale('ar', 'SA'),
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
