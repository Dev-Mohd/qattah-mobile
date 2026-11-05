import 'package:flutter/material.dart';
import 'enums.dart';

class HesabnaAppearance extends InheritedWidget {
  final Color accent;
  final AppDensity density;
  final AppCardStyle cardStyle;

  const HesabnaAppearance({
    super.key,
    required this.accent,
    required this.density,
    required this.cardStyle,
    required super.child,
  });

  static HesabnaAppearance of(BuildContext context) {
    final appearance = context.dependOnInheritedWidgetOfExactType<HesabnaAppearance>();
    assert(appearance != null, 'No HesabnaAppearance found in context');
    return appearance!;
  }

  @override
  bool updateShouldNotify(HesabnaAppearance oldWidget) {
    return accent != oldWidget.accent ||
        density != oldWidget.density ||
        cardStyle != oldWidget.cardStyle;
  }
}
