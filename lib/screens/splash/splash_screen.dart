import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/onboarding.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _start();
  }

  Future<void> _start() async {
    _controller.forward();
    _navigationTimer = Timer(const Duration(milliseconds: 1500), () async {
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;
      if (!mounted) return;
      if (seenOnboarding) {
        context.goToHome();
      } else {
        context.goToOnboarding();
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SplashLogo(size: 92),
                const SizedBox(height: 18),
                Text(
                  AppInfo.name,
                  style: HesabnaTypography.heading(color: context.cText)
                      .copyWith(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'وين قطّتكم؟',
                  style: HesabnaTypography.bodySm(color: context.cTextSub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  final double size;

  const _SplashLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/brand/qattah-logo.svg'),
      builder: (context, snapshot) {
        final svg = snapshot.data;
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: context.cAccentSoft,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.accentColor.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: svg == null
              ? Icon(Icons.receipt_long_outlined, color: context.accentColor)
              : SvgPicture.string(
                  _themeLogoSvg(svg, context),
                  fit: BoxFit.contain,
                ),
        );
      },
    );
  }

  String _themeLogoSvg(String svg, BuildContext context) {
    final accent = _hex(context.accentColor);
    final accentDark =
        _hex(Color.lerp(context.accentColor, Colors.black, 0.18)!);
    final accentLight =
        _hex(Color.lerp(context.accentColor, Colors.white, 0.42)!);
    final surface = _hex(context.cSurface);

    return svg
        .replaceAll('#064e35', accentDark)
        .replaceAll('#065f46', accent)
        .replaceAll('#10b981', accent)
        .replaceAll('#059669', accentDark)
        .replaceAll('#34d399', accentLight)
        .replaceAll('#6ee7b7', accentLight)
        .replaceAll('#fff', surface);
  }

  String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}
