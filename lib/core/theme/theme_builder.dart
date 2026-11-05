import 'package:flutter/material.dart';
import 'tokens/colors.dart';
import 'tokens/typography.dart';
import 'tokens/radius.dart';

class HesabnaTheme {
  HesabnaTheme._();

  static ThemeData buildTheme({
    required BuildContext context,
    required Brightness brightness,
    required Color accent,
  }) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
      secondary: isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
      onSecondary: isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
      surface: isLight ? HesabnaColors.lightSurface : HesabnaColors.darkSurface,
      onSurface: isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
      surfaceContainerHighest:
          isLight ? HesabnaColors.lightCard : HesabnaColors.darkCard,
      error: HesabnaColors.lightDanger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: HesabnaTypography.fontFamily,
      fontFamilyFallback: HesabnaTypography.fontFallback,
      scaffoldBackgroundColor:
          isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
      cardColor: isLight ? HesabnaColors.lightCard : HesabnaColors.darkCard,
      dividerColor:
          isLight ? HesabnaColors.lightDivider : HesabnaColors.darkBorder,
      canvasColor: isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
        foregroundColor:
            isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
        titleTextStyle: HesabnaTypography.heading(
          color: isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? HesabnaColors.lightSurface : HesabnaColors.darkSurface,
        selectedItemColor: accent,
        unselectedItemColor:
            isLight ? HesabnaColors.lightTextMuted : HesabnaColors.darkTextSub,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:
            isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
        foregroundColor: isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isLight ? HesabnaColors.lightChipBg : HesabnaColors.darkHover,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.sm),
          borderSide: BorderSide(color: accent, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: HesabnaTypography.bodySm(
          color:
              isLight ? HesabnaColors.lightTextSub : HesabnaColors.darkTextSub,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isLight ? HesabnaColors.lightText : HesabnaColors.darkText,
          foregroundColor:
              isLight ? HesabnaColors.lightBg : HesabnaColors.darkBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HesabnaRadius.md),
          ),
          textStyle: HesabnaTypography.subtitle(color: Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: HesabnaTypography.subtitle(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isLight ? HesabnaColors.lightChipBg : HesabnaColors.darkHover,
        selectedColor: accent.withValues(alpha: isLight ? 0.10 : 0.20),
        checkmarkColor: accent,
        labelStyle: HesabnaTypography.bodySm(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.full),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isLight ? HesabnaColors.lightSurface : HesabnaColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HesabnaRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:
            isLight ? HesabnaColors.lightSurface : HesabnaColors.darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(HesabnaRadius.xl2)),
        ),
      ),
    );
  }
}
