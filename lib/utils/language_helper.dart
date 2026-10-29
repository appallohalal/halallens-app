import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageHelper {
  static const List<Map<String, String>> languages = [
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
    {'code': 'it', 'name': 'Italian', 'nativeName': 'Italiano'},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português'},
    {'code': 'tr', 'name': 'Turkish', 'nativeName': 'Türkçe'},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский'},
  ];

  static String getLanguageName(BuildContext context) {
    final code = context.locale.languageCode;
    final lang = languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => languages.first,
    );
    return lang['name']!;
  }

  static String getNativeLanguageName(BuildContext context) {
    final code = context.locale.languageCode;
    final lang = languages.firstWhere(
      (l) => l['code'] == code,
      orElse: () => languages.first,
    );
    return lang['nativeName']!;
  }
}
