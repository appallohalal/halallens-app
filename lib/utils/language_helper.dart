import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguageHelper {
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
    {'code': 'ur', 'name': 'Urdu', 'nativeName': 'اردو'},
    {'code': 'tr', 'name': 'Turkish', 'nativeName': 'Türkçe'},
    {'code': 'id', 'name': 'Indonesian', 'nativeName': 'Bahasa Indonesia'},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
    {'code': 'zh', 'name': 'Chinese', 'nativeName': '中文'},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский'},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português'},
    {'code': 'it', 'name': 'Italian', 'nativeName': 'Italiano'},
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
