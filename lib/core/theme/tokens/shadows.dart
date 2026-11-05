import 'package:flutter/material.dart';

class HesabnaShadow {
  HesabnaShadow._();

  static List<BoxShadow> get light => [
    BoxShadow(
      color: const Color(0xFF0F1117).withValues(alpha: 0.04),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF0F1117).withValues(alpha: 0.08),
      blurRadius: 16,
      spreadRadius: -8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: const Color(0xFF0F1117).withValues(alpha: 0.14),
      blurRadius: 28,
      spreadRadius: -10,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F1117).withValues(alpha: 0.04),
      blurRadius: 1,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get dark => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
