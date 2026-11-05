import 'package:flutter/material.dart';
import 'tokens/spacing.dart';

class HesabnaLayout {
  HesabnaLayout._();

  static EdgeInsets get pagePadding => const EdgeInsets.symmetric(
    horizontal: HesabnaSpacing.comfortablePagePad,
    vertical: HesabnaSpacing.lg,
  );

  static EdgeInsets get compactPagePadding => const EdgeInsets.symmetric(
    horizontal: HesabnaSpacing.compactPagePad,
    vertical: HesabnaSpacing.md,
  );

  static EdgeInsets get bottomNavPadding => const EdgeInsets.only(
    bottom: HesabnaSpacing.bottomNavPad,
  );
}
