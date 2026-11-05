import 'package:flutter/material.dart';

import '../../core/legal_documents.dart';
import '../../core/router.dart';
import '../../core/theme/hesabna_theme.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  int _index = 0;

  LegalDocument get _document =>
      _index == 0 ? privacyPolicy : termsAndConditions;

  @override
  Widget build(BuildContext context) {
    final document = _document;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        title: const Text('الشروط والخصوصية'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: context.goToSettings,
        ),
      ),
      body: FadeInWidget(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.pagePad,
            context.pagePad,
            context.pagePad,
            context.pagePad + 24,
          ),
          children: [
            _Tabs(
              selectedIndex: _index,
              onChanged: (index) => setState(() => _index = index),
            ),
            SizedBox(height: context.sectionGap),
            _DocumentHeader(document: document),
            const SizedBox(height: 14),
            ...document.sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LegalSectionCard(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cHover,
        borderRadius: BorderRadius.circular(HesabnaRadius.md),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'الخصوصية',
            icon: Icons.privacy_tip_outlined,
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: 'الشروط',
            icon: Icons.description_outlined,
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HesabnaRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? context.cSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(HesabnaRadius.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? context.accentColor : context.cTextSub,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: HesabnaTypography.subtitle(
                  color: selected ? context.cText : context.cTextSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  final LegalDocument document;

  const _DocumentHeader({required this.document});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: HesabnaTypography.heading(color: context.cText),
          ),
          const SizedBox(height: 4),
          Text(
            'آخر تحديث: ${document.updatedAt}',
            style: HesabnaTypography.caption(color: context.cTextMuted),
          ),
        ],
      ),
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  final LegalSection section;

  const _LegalSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return HesabnaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: HesabnaTypography.subtitle(color: context.cText),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: HesabnaTypography.bodySm(color: context.cTextSub),
          ),
        ],
      ),
    );
  }
}
