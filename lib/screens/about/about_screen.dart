import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: const Text('عن التطبيق'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: context.goToSettings,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pagePad,
          context.pagePad,
          context.pagePad,
          HesabnaSpacing.bottomNavPad,
        ),
        children: [
          const _AboutHero(),
          SizedBox(height: context.sectionGap),
          const _LinksCard(),
          SizedBox(height: context.sectionGap),
          const _MadeByCard(),
        ],
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.xl),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        children: [
          const _ThemedLogo(size: 74),
          const SizedBox(height: 14),
          Text(
            AppInfo.name,
            style: HesabnaTypography.heading(color: context.cText).copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تنظيم وجبات العمل وحساب النصيب والسداد بوضوح.',
            textAlign: TextAlign.center,
            style: HesabnaTypography.bodySm(color: context.cTextSub),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: context.cAccentSoft,
              borderRadius: BorderRadius.circular(HesabnaRadius.full),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              'Version ${AppInfo.version}',
              textDirection: TextDirection.ltr,
              style: HesabnaTypography.caption(color: context.accentColor)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemedLogo extends StatelessWidget {
  final double size;

  const _ThemedLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: rootBundle.loadString('assets/brand/qattah-logo.svg'),
      builder: (context, snapshot) {
        final svg = snapshot.data;
        return Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.cAccentSoft,
            borderRadius: BorderRadius.circular(HesabnaRadius.lg),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.28),
            ),
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

class _LinksCard extends StatelessWidget {
  const _LinksCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        border: Border.all(color: context.cBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          _LinkRow(
            icon: Icons.alternate_email_rounded,
            title: 'إنستغرام التطبيق',
            value: '@qattah.app',
            url: Uri.parse('https://instagram.com/qattah.app'),
          ),
          Divider(height: 1, indent: 16, color: context.cDivider),
          _LinkRow(
            icon: Icons.language_rounded,
            title: 'صفحة المطور',
            value: 'dev-mohd.com',
            url: Uri.parse('https://dev-mohd.com'),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Uri url;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.cAccentSoft,
                borderRadius: BorderRadius.circular(HesabnaRadius.md),
              ),
              child: Icon(icon, size: 19, color: context.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: HesabnaTypography.body(color: context.cText)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    textDirection: TextDirection.ltr,
                    style: HesabnaTypography.caption(color: context.cTextMuted)
                        .copyWith(fontFamily: 'NotoSans'),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 18, color: context.cTextMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, Uri url) async {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط')),
      );
    }
  }
}

class _MadeByCard extends StatelessWidget {
  const _MadeByCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'صنع',
            style: HesabnaTypography.caption(color: context.cTextSub),
          ),
          const SizedBox(height: 8),
          Icon(
            Icons.favorite_rounded,
            color: context.accentColor,
            size: 26,
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              'DevMohd',
              style: TextStyle(
                color: context.cText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: 0.2,
                fontFamilyFallback: const ['NotoSans'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
