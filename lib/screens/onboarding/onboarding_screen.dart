import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/onboarding.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.groups_2_outlined,
      eyebrow: 'الخطوة 1',
      title: 'أنشئ قائمة للمجموعة',
      body:
          'القائمة هي مكان الفريق: فطور الدوام، قهوة المكتب، أو أي مجموعة تتقاسم المصاريف.',
      points: [
        'اكتب اسم القائمة',
        'أضف أعضاء المجموعة',
        'حدد الوجبات أو البنود المتكررة',
      ],
    ),
    _OnboardingPageData(
      icon: Icons.fact_check_outlined,
      eyebrow: 'الخطوة 2',
      title: 'اختر الحاضرين',
      body:
          'عند تسجيل وجبة، اختر من حضر فقط. التطبيق يحسب النصيب على الحاضرين بدون ما تحتاج تقسمها يدويًا.',
      points: [
        'اختر نوع الوجبة',
        'حدد الحاضرين',
        'أدخل المبلغ الإجمالي',
      ],
    ),
    _OnboardingPageData(
      icon: Icons.payments_outlined,
      eyebrow: 'الخطوة 3',
      title: 'سجل السداد',
      body:
          'إذا دفع العضو كامل المبلغ أو جزء منه، سجله من صفحة الأرصدة ويبقى المتبقي واضحًا.',
      points: [
        'اضغط اسم العضو',
        'اختر تسجيل سداد',
        'اكتب المبلغ المدفوع',
      ],
    ),
    _OnboardingPageData(
      icon: Icons.auto_awesome_rounded,
      eyebrow: 'الخطوة 4',
      title: 'راجع الوضع بسرعة',
      body:
          'الصفحة الرئيسية والتقارير تعطيك صورة واضحة: الأكثر مديونية، آخر النشاط، والتقرير الشهري.',
      points: [
        'تابع أعلى مديونية',
        'شارك تقرير PDF',
        'راجع التنبيهات الذكية',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePad,
            18,
            context.pagePad,
            context.pagePad,
          ),
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('تخطي'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPage(data: page);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final active = index == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: active ? context.accentColor : context.cBorder,
                      borderRadius: BorderRadius.circular(HesabnaRadius.full),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isLast ? _finish : _next,
                icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_back_rounded),
                label: Text(isLast ? 'ابدأ الآن' : 'التالي'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingSeenKey, true);
    if (!mounted) return;
    context.goToHome();
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> points;

  const _OnboardingPageData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: context.cAccentSoft,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(data.icon, size: 48, color: context.accentColor),
        ),
        const SizedBox(height: 32),
        Text(
          data.eyebrow,
          textAlign: TextAlign.center,
          style: HesabnaTypography.label(color: context.accentColor),
        ),
        const SizedBox(height: 8),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: HesabnaTypography.heading(color: context.cText)
              .copyWith(fontSize: 28),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            data.body,
            textAlign: TextAlign.center,
            style: HesabnaTypography.body(color: context.cTextSub)
                .copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Column(
            children: data.points
                .map((point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TrainingPoint(text: point),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TrainingPoint extends StatelessWidget {
  final String text;

  const _TrainingPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cCard,
        borderRadius: BorderRadius.circular(HesabnaRadius.md),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 18, color: context.accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: HesabnaTypography.caption(color: context.cText),
            ),
          ),
        ],
      ),
    );
  }
}
