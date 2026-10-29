import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Server-driven Dynamic UI Text / CMS Configuration.
/// Syncs customizable titles, descriptions, onboarding slides, and policy pages
/// from the Admin Panel (`public.cms_settings`) and deep-merges them into EasyLocalization.
class CmsConfig {
  CmsConfig._();

  static const String _prefKeyCachedCms = 'cached_cms_remote_config';

  static Map<String, dynamic> _texts = {};
  static DateTime? _lastSyncedAt;
  static final ValueNotifier<int> updateNotifier = ValueNotifier<int>(0);

  static Map<String, dynamic> get texts => _texts;
  static DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Helper to get a dynamic CMS text by key with fallback
  static String getText(String key, {String fallback = ''}) {
    final val = _texts[key];
    if (val is String && val.trim().isNotEmpty) {
      return val;
    }
    return fallback;
  }

  static String get geoAdsNoticeText => getText(
        'geoAdsNoticeText',
        fallback: 'home.geo_ads_notice_text'.tr(),
      );

  /// Map of Admin CMS keys to EasyLocalization nested JSON paths (`section.key`)
  static const Map<String, List<String>> _cmsKeyToLocalePath = {
    'appName': ['general', 'app_name'],
    'splashSubtitle': ['general', 'splash_subtitle'],
    'heroSubtitle': ['home', 'hero_subtitle'],
    'scanBarcodeBtn': ['home', 'scan_barcode'],
    'analyzeTextBtn': ['home', 'analyze_text'],
    'manualEntryBtn': ['home', 'manual_entry'],

    'feature1Title': ['home', 'feature_1_title'],
    'feature1Desc': ['home', 'feature_1_desc'],
    'feature2Title': ['home', 'feature_2_title'],
    'feature2Desc': ['home', 'feature_2_desc'],
    'feature3Title': ['home', 'feature_3_title'],
    'feature3Desc': ['home', 'feature_3_desc'],

    'onboarding1Title': ['onboarding', 'title_1'],
    'onboarding1Desc': ['onboarding', 'desc_1'],
    'onboarding2Title': ['onboarding', 'title_2'],
    'onboarding2Desc': ['onboarding', 'desc_2'],
    'onboarding3Title': ['onboarding', 'title_3'],
    'onboarding3Desc': ['onboarding', 'desc_3'],
    'onboarding4Title': ['onboarding', 'title_4'],
    'onboarding4Desc': ['onboarding', 'desc_4'],

    'loginTitle': ['auth', 'welcome_back'],
    'loginSubtitle': ['auth', 'login_subtitle'],
    'registerTitle': ['auth', 'create_your_account'],
    'registerSubtitle': ['auth', 'register_subtitle'],
    'textScanTitle': ['text_scan', 'title'],
    'textScanSubtitle': ['text_scan', 'subtitle'],
    'resultDisclaimer': ['result', 'disclaimer'],

    'aboutTitle': ['settings', 'about_title'],
    'aboutContent': ['settings', 'about_content'],
    'helpTitle': ['settings', 'help_title'],
    'helpContent': ['settings', 'help_content'],
    'privacyTitle': ['settings', 'privacy_title'],
    'privacyContent': ['settings', 'privacy_content'],
    'termsTitle': ['auth', 'terms_title'],
    'termsContent': ['auth', 'terms_content'],
    'geoAdsNoticeText': ['home', 'geo_ads_notice_text'],
  };

  /// Sync remote CMS texts from Supabase Cloud / Admin API
  static Future<void> syncFromBackend() async {
    await loadCachedOnly();

    bool synced = false;

    // 1. Primary: Fetch directly from Supabase REST API for ultra-low latency
    try {
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/cms_settings?id=eq.global&select=*',
      );

      final response = await http.get(
        supabaseUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          final rawTexts = row['texts'];
          if (rawTexts is Map<String, dynamic>) {
            _texts = Map<String, dynamic>.from(rawTexts);
            _lastSyncedAt = DateTime.now();

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKeyCachedCms, jsonEncode(_texts));
            synced = true;
            updateNotifier.value++;

            if (kDebugMode) {
              debugPrint(
                '✅ [CmsConfig] Synced ${_texts.length} dynamic UI texts from Supabase',
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ [CmsConfig] Supabase direct sync note: $e');
      }
    }

    // 2. Fallback: Fetch from Admin Backend `/api/v1/cms`
    if (!synced) {
      try {
        final uri = Uri.parse('${AppConfig.backendBaseUrl}/cms');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final rawTexts = data['texts'];
          if (rawTexts is Map<String, dynamic>) {
            _texts = Map<String, dynamic>.from(rawTexts);
            _lastSyncedAt = DateTime.now();

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKeyCachedCms, jsonEncode(_texts));
            updateNotifier.value++;

            if (kDebugMode) {
              debugPrint('✅ [CmsConfig] Synced dynamic UI texts from Admin API');
            }
          }
        }
      } catch (_) {}
    }
  }

  /// Fast local-only load from SharedPreferences (< 5ms, never blocks startup)
  static Future<void> loadCachedOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefKeyCachedCms);
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic>) {
          _texts = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
  }

  /// Applies dynamic CMS overrides onto a loaded translation map
  static Map<String, dynamic> applyOverrides(Map<String, dynamic> baseMap) {
    if (_texts.isEmpty) return baseMap;

    for (final entry in _cmsKeyToLocalePath.entries) {
      final cmsKey = entry.key;
      final path = entry.value;
      final customValue = _texts[cmsKey];

      if (customValue is String && customValue.trim().isNotEmpty) {
        final section = path[0];
        final field = path[1];
        if (baseMap[section] is Map<String, dynamic>) {
          (baseMap[section] as Map<String, dynamic>)[field] = customValue;
        } else if (baseMap[section] is Map) {
          final copy = Map<String, dynamic>.from(baseMap[section] as Map);
          copy[field] = customValue;
          baseMap[section] = copy;
        }
      }
    }

    return baseMap;
  }
}

/// Custom EasyLocalization AssetLoader that merges bundled JSON translations
/// with live CMS overrides from the Admin Panel.
class CmsAssetLoader extends AssetLoader {
  const CmsAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final fullPath = '$path/${locale.languageCode}.json';
    final jsonString = await rootBundle.loadString(fullPath);
    final Map<String, dynamic> baseMap =
        Map<String, dynamic>.from(jsonDecode(jsonString) as Map);

    return CmsConfig.applyOverrides(baseMap);
  }
}

