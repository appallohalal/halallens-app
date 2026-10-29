import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryBlue = Color(0xFF088839);
  static const Color darkBlue = Color(0xFF066D2E);
  static const Color lightBlue = Color(0xFFE6F4EB);

  static const Color backgroundDark = Color(0xFF0D1117);
  static const Color surfaceDark = Color(0xFF161B22);
  static const Color cardDark = Color(0xFF1C2333);
  static const Color borderDark = Color(0xFF30363D);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  static const Color haramRed = Color(0xFFD32F2F);
  static const Color doubtfulAmber = Color(0xFFD97706);
  static const Color halalGreen = Color(0xFF088839);
  static const Color unknownGrey = Color(0xFF64748B);

  static const Color haramSolid = Color(0xFFC62828);
  static const Color doubtfulSolid = Color(0xFFD97706);
  static const Color halalSolid = Color(0xFF088839);

  // High-contrast status text/icon colors for Light & Dark modes
  static Color getHaramTextColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

  static Color getHaramBgColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFFEF4444).withValues(alpha: 0.16)
          : const Color(0xFFFEE2E2);

  static Color getHaramBorderColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFFF87171).withValues(alpha: 0.4)
          : const Color(0xFFFCA5A5);

  static Color getDoubtfulTextColor(BuildContext context) =>
      isDark(context) ? const Color(0xFFFBBF24) : const Color(0xFF92400E);

  static Color getDoubtfulBgColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
          : const Color(0xFFFEF3C7);

  static Color getDoubtfulBorderColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFFFBBF24).withValues(alpha: 0.45)
          : const Color(0xFFF59E0B);

  static Color getHalalTextColor(BuildContext context) =>
      isDark(context) ? const Color(0xFF34D399) : const Color(0xFF065F46);

  static Color getHalalBgColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF10B981).withValues(alpha: 0.16)
          : const Color(0xFFD1FAE5);

  static Color getHalalBorderColor(BuildContext context) =>
      isDark(context)
          ? const Color(0xFF34D399).withValues(alpha: 0.4)
          : const Color(0xFF6EE7B7);

  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE9ECEF);

  static const Color textPrimaryLight = Color(0xFF212529);
  static const Color textSecondaryLight = Color(0xFF495057);
  static const Color textMutedLight = Color(0xFFadb5bd);

  static Color getBackgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color getSurfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color getCardColor(BuildContext context) =>
      Theme.of(context).cardTheme.color!;
  static Color getBorderColor(BuildContext context) =>
      (Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side.color;
  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textPrimary
      : textPrimaryLight;
  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textSecondary
      : textSecondaryLight;
  static Color getTextMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? textMuted
      : textMutedLight;
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ThemeData lightTheme(BuildContext context) {
    final baseTheme = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: AppFonts.textTheme(context, baseTheme.textTheme).copyWith(
        bodyLarge: AppFonts.primary(context, color: textPrimaryLight),
        bodyMedium: AppFonts.primary(context, color: textPrimaryLight),
        labelLarge: AppFonts.primary(context, color: textPrimaryLight),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: Color(0xFF34D399),
        surface: surfaceLight,
        error: haramRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: backgroundLight,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: AppFonts.primary(
          context,
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimaryLight),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppFonts.primary(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: AppFonts.primary(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        hintStyle: AppFonts.primary(context, color: textMutedLight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimaryLight,
        contentTextStyle: AppFonts.primary(context, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: borderLight,
        disabledColor: borderLight,
        selectedColor: primaryBlue,
        secondarySelectedColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: AppFonts.primary(
          context,
          color: textPrimaryLight,
          fontSize: 13,
        ),
        secondaryLabelStyle: AppFonts.primary(
          context,
          color: Colors.white,
          fontSize: 13,
        ),
        brightness: Brightness.light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData darkTheme(BuildContext context) {
    final baseTheme = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: AppFonts.textTheme(context, baseTheme.textTheme).copyWith(
        bodyLarge: AppFonts.primary(context, color: textPrimary),
        bodyMedium: AppFonts.primary(context, color: textPrimary),
        labelLarge: AppFonts.primary(context, color: textPrimary),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: Color(0xFF34D399),
        surface: surfaceDark,
        error: haramRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: backgroundDark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: AppFonts.primary(
          context,
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppFonts.primary(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: AppFonts.primary(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        hintStyle: AppFonts.primary(context, color: textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle: AppFonts.primary(context, color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: borderDark,
        disabledColor: borderDark,
        selectedColor: primaryBlue,
        secondarySelectedColor: primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: AppFonts.primary(context, color: textPrimary, fontSize: 13),
        secondaryLabelStyle: AppFonts.primary(
          context,
          color: Colors.white,
          fontSize: 13,
        ),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
