import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Purely server-driven AdMob configuration for Android and iOS.
/// No hardcoded ad unit IDs in the app — whatever ID is returned from the server
/// (Test ID or Production ID) is used directly based on the platform.
class AdConfig {
  AdConfig._();

  static const String _prefKeyCachedAdmob = 'cached_admob_remote_config';

  static String _appId = '';
  static String _bannerId = '';
  static String _interstitialId = '';
  static String _appOpenId = '';
  static String _nativeId = '';
  static String _rewardedId = '';

  static bool _bannerEnabled = true;
  static bool _interstitialEnabled = true;
  static bool _appOpenEnabled = true;
  static bool _nativeEnabled = true;
  static bool _rewardedEnabled = false;

  static int _interstitialIntervalScans = 3;
  static int _appOpenCooldownMinutes = 15;
  static int _bannerRefreshRateSeconds = 60;

  // ===========================================================================
  // Public Dynamic Getters (Used throughout the App & Widgets)
  // ===========================================================================

  /// True if server provided active ad unit IDs
  static bool get adsEnabled =>
      _bannerId.isNotEmpty ||
      _interstitialId.isNotEmpty ||
      _appOpenId.isNotEmpty ||
      _nativeId.isNotEmpty;

  /// Android AdMob App ID
  static String get appId => _appId;

  /// Ad Unit IDs directly from server
  static String get bannerAdUnitId => _bannerId;
  static String get interstitialAdUnitId => _interstitialId;
  static String get appOpenAdUnitId => _appOpenId;
  static String get nativeAdUnitId => _nativeId;
  static String get rewardedAdUnitId => _rewardedId;

  /// Format toggles (checked before loading respective ads)
  static bool get bannerEnabled => _bannerEnabled && _bannerId.isNotEmpty;
  static bool get interstitialEnabled =>
      _interstitialEnabled && _interstitialId.isNotEmpty;
  static bool get appOpenEnabled => _appOpenEnabled && _appOpenId.isNotEmpty;
  static bool get nativeEnabled => _nativeEnabled && _nativeId.isNotEmpty;
  static bool get rewardedEnabled => _rewardedEnabled && _rewardedId.isNotEmpty;

  /// Frequency capping
  static int get interstitialIntervalScans => _interstitialIntervalScans;
  static int get appOpenCooldownMinutes => _appOpenCooldownMinutes;
  static int get bannerRefreshRateSeconds => _bannerRefreshRateSeconds;

  // ===========================================================================
  // Remote Synchronization Methods
  // ===========================================================================

  /// Initialize and load cached config immediately, then fetch live from Admin
  static Future<void> syncFromBackend() async {
    // 1. Immediately apply cached config from SharedPreferences if present
    await _loadCachedConfig();

    bool synced = false;

    // 2. Primary: Fetch directly from Supabase Cloud REST API for ultra-low latency
    try {
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/admob_settings?id=eq.global&select=*',
      );

      final response = await http.get(
        supabaseUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          _applySupabaseRow(row);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedAdmob, jsonEncode(row));
          synced = true;
        }
      }
    } catch (_) {}

    // 3. Fallback: Admin backend API
    if (!synced) {
      try {
        final platformParam = (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';
        final uri =
            Uri.parse('${AppConfig.backendBaseUrl}/admob?platform=$platformParam');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _applyRemoteConfig(data);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedAdmob, response.body);
          synced = true;
        }
      } catch (_) {}
    }
  }

  static Future<void> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_prefKeyCachedAdmob);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final data = jsonDecode(cachedJson);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('bannerId') || data.containsKey('activeIds')) {
            _applyRemoteConfig(data);
          } else if (data.containsKey('android_banner_id') ||
              data.containsKey('banner_id_android') ||
              data.containsKey('ads_enabled')) {
            _applySupabaseRow(data);
          }
        }
      }
    } catch (_) {}
  }

  static void _applyRemoteConfig(Map<String, dynamic> data) {
    if (data['adsEnabled'] == false) {
      _bannerId = '';
      _interstitialId = '';
      _appOpenId = '';
      _nativeId = '';
      _rewardedId = '';
      return;
    }

    // Direct unit IDs from server
    if (data['bannerId'] != null && (data['bannerId'] as String).isNotEmpty) {
      _bannerId = data['bannerId'] as String;
    }
    if (data['interstitialId'] != null &&
        (data['interstitialId'] as String).isNotEmpty) {
      _interstitialId = data['interstitialId'] as String;
    }
    if (data['appOpenId'] != null &&
        (data['appOpenId'] as String).isNotEmpty) {
      _appOpenId = data['appOpenId'] as String;
    }
    if (data['nativeId'] != null && (data['nativeId'] as String).isNotEmpty) {
      _nativeId = data['nativeId'] as String;
    }
    if (data['rewardedId'] != null &&
        (data['rewardedId'] as String).isNotEmpty) {
      _rewardedId = data['rewardedId'] as String;
    }
    if (data['appId'] != null && (data['appId'] as String).isNotEmpty) {
      _appId = data['appId'] as String;
    }

    // Support nested activeIds as well
    final activeIds = data['activeIds'] as Map<String, dynamic>?;
    if (activeIds != null) {
      _appId = (activeIds['appId'] as String?) ?? _appId;
      _bannerId = (activeIds['bannerId'] as String?) ?? _bannerId;
      _interstitialId =
          (activeIds['interstitialId'] as String?) ?? _interstitialId;
      _appOpenId = (activeIds['appOpenId'] as String?) ?? _appOpenId;
      _nativeId = (activeIds['nativeId'] as String?) ?? _nativeId;
      _rewardedId = (activeIds['rewardedId'] as String?) ?? _rewardedId;
    }

    final formats = data['formats'] as Map<String, dynamic>?;
    if (formats != null) {
      _bannerEnabled = formats['banner'] != false;
      _interstitialEnabled = formats['interstitial'] != false;
      _appOpenEnabled = formats['appOpen'] != false;
      _nativeEnabled = formats['native'] != false;
      _rewardedEnabled = formats['rewarded'] == true;
    }

    final frequency = data['frequency'] as Map<String, dynamic>?;
    if (frequency != null) {
      _interstitialIntervalScans =
          (frequency['interstitialIntervalScans'] as num?)?.toInt() ?? 3;
      _appOpenCooldownMinutes =
          (frequency['appOpenCooldownMinutes'] as num?)?.toInt() ?? 15;
      _bannerRefreshRateSeconds =
          (frequency['bannerRefreshRateSeconds'] as num?)?.toInt() ?? 60;
    }
  }

  static void _applySupabaseRow(Map<String, dynamic> row) {
    final adsEnabled = row['ads_enabled'] == true;
    if (!adsEnabled) {
      _bannerId = '';
      _interstitialId = '';
      _appOpenId = '';
      _nativeId = '';
      _rewardedId = '';
      return;
    }

    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      // 1. iOS Unit IDs
      final iosAppId = row['ios_app_id'] as String?;
      final testIosAppId = row['test_ios_app_id'] as String?;
      _appId = (iosAppId != null && iosAppId.isNotEmpty)
          ? iosAppId
          : (testIosAppId ?? '');

      final iosBannerId =
          (row['ios_banner_id'] ?? row['banner_id_ios']) as String?;
      final testIosBannerId = row['test_ios_banner_id'] as String?;
      _bannerId = (iosBannerId != null && iosBannerId.isNotEmpty)
          ? iosBannerId
          : (testIosBannerId ?? '');

      final iosInterstitialId = (row['ios_interstitial_id'] ??
          row['interstitial_id_ios']) as String?;
      final testIosInterstitialId =
          row['test_ios_interstitial_id'] as String?;
      _interstitialId =
          (iosInterstitialId != null && iosInterstitialId.isNotEmpty)
              ? iosInterstitialId
              : (testIosInterstitialId ?? '');

      final iosAppOpenId = row['ios_app_open_id'] as String?;
      final testIosAppOpenId = row['test_ios_app_open_id'] as String?;
      _appOpenId = (iosAppOpenId != null && iosAppOpenId.isNotEmpty)
          ? iosAppOpenId
          : (testIosAppOpenId ?? '');

      final iosNativeId = row['ios_native_id'] as String?;
      final testIosNativeId = row['test_ios_native_id'] as String?;
      _nativeId = (iosNativeId != null && iosNativeId.isNotEmpty)
          ? iosNativeId
          : (testIosNativeId ?? '');

      final iosRewardedId =
          (row['ios_rewarded_id'] ?? row['rewarded_id_ios']) as String?;
      final testIosRewardedId = row['test_ios_rewarded_id'] as String?;
      _rewardedId = (iosRewardedId != null && iosRewardedId.isNotEmpty)
          ? iosRewardedId
          : (testIosRewardedId ?? '');
    } else {
      // 2. Android Unit IDs
      final androidAppId = row['android_app_id'] as String?;
      final testAndroidAppId = row['test_android_app_id'] as String?;
      _appId = (androidAppId != null && androidAppId.isNotEmpty)
          ? androidAppId
          : (testAndroidAppId ?? '');

      final androidBannerId =
          (row['android_banner_id'] ?? row['banner_id_android']) as String?;
      final testAndroidBannerId = row['test_android_banner_id'] as String?;
      _bannerId = (androidBannerId != null && androidBannerId.isNotEmpty)
          ? androidBannerId
          : (testAndroidBannerId ?? '');

      final androidInterstitialId = (row['android_interstitial_id'] ??
          row['interstitial_id_android']) as String?;
      final testAndroidInterstitialId =
          row['test_android_interstitial_id'] as String?;
      _interstitialId =
          (androidInterstitialId != null && androidInterstitialId.isNotEmpty)
              ? androidInterstitialId
              : (testAndroidInterstitialId ?? '');

      final androidAppOpenId = row['android_app_open_id'] as String?;
      final testAndroidAppOpenId = row['test_android_app_open_id'] as String?;
      _appOpenId = (androidAppOpenId != null && androidAppOpenId.isNotEmpty)
          ? androidAppOpenId
          : (testAndroidAppOpenId ?? '');

      final androidNativeId = row['android_native_id'] as String?;
      final testAndroidNativeId = row['test_android_native_id'] as String?;
      _nativeId = (androidNativeId != null && androidNativeId.isNotEmpty)
          ? androidNativeId
          : (testAndroidNativeId ?? '');

      final androidRewardedId =
          (row['android_rewarded_id'] ?? row['rewarded_id_android']) as String?;
      final testAndroidRewardedId = row['test_android_rewarded_id'] as String?;
      _rewardedId = (androidRewardedId != null && androidRewardedId.isNotEmpty)
          ? androidRewardedId
          : (testAndroidRewardedId ?? '');
    }

    _bannerEnabled = row['banner_enabled'] != false;
    _interstitialEnabled = row['interstitial_enabled'] != false;
    _appOpenEnabled = row['app_open_enabled'] != false;
    _nativeEnabled = row['native_enabled'] != false;
    _rewardedEnabled = row['rewarded_enabled'] == true;

    _interstitialIntervalScans = ((row['interstitial_interval_scans'] ??
            row['interstitial_frequency']) as num?)
        ?.toInt() ??
        3;
    _appOpenCooldownMinutes =
        (row['app_open_cooldown_minutes'] as num?)?.toInt() ?? 15;
    _bannerRefreshRateSeconds =
        (row['banner_refresh_rate_seconds'] as num?)?.toInt() ?? 60;
  }
}
