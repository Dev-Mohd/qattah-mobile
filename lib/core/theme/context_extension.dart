import 'package:flutter/material.dart';
import 'appearance.dart';
import 'tokens/colors.dart';
import 'tokens/spacing.dart';
import 'enums.dart';

extension BuildContextHesabna on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  HesabnaAppearance get appearance => HesabnaAppearance.of(this);

  Color get accentColor => appearance.accent;
  AppDensity get density => appearance.density;
  AppCardStyle get cardStyle => appearance.cardStyle;

  Color get cAccentSoft => accentColor.withValues(alpha: isDark ? 0.20 : 0.10);
  Color get cAccentSofter => accentColor.withValues(alpha: isDark ? 0.12 : 0.07);
  Color get cOnAccent => isDark ? HesabnaColors.darkBg : HesabnaColors.lightBg;

  Color get cBg => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightBg : HesabnaColors.darkBg;

  Color get cSurface => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightSurface : HesabnaColors.darkSurface;

  Color get cCard => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightCard : HesabnaColors.darkCard;

  Color get cBorder => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightBorder : HesabnaColors.darkBorder;

  Color get cText => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightText : HesabnaColors.darkText;

  Color get cTextSub => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightTextSub : HesabnaColors.darkTextSub;

  Color get cTextMuted => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightTextMuted : HesabnaColors.darkTextMuted;

  Color get cHover => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightHover : HesabnaColors.darkHover;

  Color get cElevated => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightElevated : HesabnaColors.darkElevated;

  Color get cDivider => Theme.of(this).brightness == Brightness.light
      ? HesabnaColors.lightDivider : HesabnaColors.darkBorder;

  double get pagePad => density == AppDensity.comfortable
      ? HesabnaSpacing.comfortablePagePad : HesabnaSpacing.compactPagePad;

  double get cardPad => density == AppDensity.comfortable
      ? HesabnaSpacing.comfortableCardPad : HesabnaSpacing.compactCardPad;

  double get sectionGap => density == AppDensity.comfortable
      ? HesabnaSpacing.comfortableSectionGap : HesabnaSpacing.compactSectionGap;

  double get itemGap => density == AppDensity.comfortable
      ? HesabnaSpacing.comfortableItemGap : HesabnaSpacing.compactItemGap;

  double get rowHeight => density == AppDensity.comfortable
      ? HesabnaSpacing.comfortableRowHeight : HesabnaSpacing.compactRowHeight;
}
