import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class AppFonts {
  static TextStyle primary(
    BuildContext context, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    final lang = context.locale.languageCode;
    TextStyle baseStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      decoration: decoration,
    );

    switch (lang) {
      case 'bn':
        return GoogleFonts.hindSiliguri().merge(baseStyle);
      case 'hi':
        return GoogleFonts.hind().merge(baseStyle);
      case 'zh':
        return GoogleFonts.notoSansSc().merge(baseStyle);
      case 'ur':
        // Vazirmatn is a very popular, modern and highly readable font for Urdu/Arabic apps
        return GoogleFonts.vazirmatn().merge(baseStyle);
      case 'ar':
        return GoogleFonts.cairo().merge(baseStyle);
      case 'id':
      case 'tr':
      case 'fr':
      case 'es':
      case 'de':
      case 'en':
      default:
        return GoogleFonts.poppins().merge(baseStyle);
    }
  }

  static TextStyle secondary(
    BuildContext context, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
  }) {
    final lang = context.locale.languageCode;
    TextStyle baseStyle = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
    );

    switch (lang) {
      case 'bn':
        return GoogleFonts.notoSansBengali().merge(baseStyle);
      case 'hi':
        return GoogleFonts.hind().merge(baseStyle);
      case 'zh':
        return GoogleFonts.notoSansSc().merge(baseStyle);
      case 'ur':
        return GoogleFonts.vazirmatn().merge(baseStyle);
      case 'ar':
        return GoogleFonts.cairo().merge(baseStyle);
      case 'id':
      case 'tr':
      case 'fr':
      case 'en':
      default:
        return GoogleFonts.inter().merge(baseStyle);
    }
  }

  static TextTheme textTheme(BuildContext context, TextTheme base) {
    final lang = context.locale.languageCode;
    switch (lang) {
      case 'bn':
        return GoogleFonts.hindSiliguriTextTheme(base);
      case 'hi':
        return GoogleFonts.hindTextTheme(base);
      case 'zh':
        return GoogleFonts.notoSansScTextTheme(base);
      case 'ur':
        return GoogleFonts.vazirmatnTextTheme(base);
      case 'ar':
        return GoogleFonts.cairoTextTheme(base);
      case 'id':
      case 'tr':
      case 'fr':
      case 'es':
      case 'de':
      case 'en':
      default:
        return GoogleFonts.poppinsTextTheme(base);
    }
  }
}
