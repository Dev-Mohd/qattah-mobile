import 'package:flutter/material.dart';

class HesabnaTypography {
  HesabnaTypography._();

  static const String fontFamily = 'IBMPlexSansArabic';
  static const String monoFamily = 'IBMPlexMono';
  static const List<String> fontFallback = ['SaudiRiyal'];

  static TextStyle amountHero({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle amountLarge({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      );

  static TextStyle amountSmall({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
      );

  static TextStyle heading({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: color,
      );

  static TextStyle title({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: color,
      );

  static TextStyle subtitle({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.5,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle label({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: color,
        letterSpacing: 0,
      );

  static TextStyle monoAmount({Color? color, double? fontSize}) => TextStyle(
        fontFamily: monoFamily,
        fontFamilyFallback: fontFallback,
        fontSize: fontSize ?? 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: color,
        letterSpacing: 0,
      );
}
