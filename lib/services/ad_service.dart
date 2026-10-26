import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';

class AdService {
  AdService._();

  static final AdService _instance = AdService._();
  static AdService get instance => _instance;

  static const String _keyLastInterstitialTime = 'ad_last_interstitial_ts';
  static const int _minInterstitialIntervalSeconds = 90;
  static const String _keyLastAppOpenTime = 'ad_last_app_open_ts';

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;

  bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    // 1. Sync live configuration from HalalLens Admin backend
    await AdConfig.syncFromBackend();

    if (kDebugMode) {
      debugPrint(
        '📢 [AdService] Initializing: adsEnabled=${AdConfig.adsEnabled}, '
        'bannerId=${AdConfig.bannerAdUnitId}',
      );
    }

    if (!AdConfig.adsEnabled || _instance._isInitialized) return;
    await MobileAds.instance.initialize();
    _instance._isInitialized = true;

    if (kDebugMode) {
      debugPrint('✅ [AdService] Google Mobile Ads initialized successfully!');
    }

    if (AdConfig.appOpenEnabled) {
      _instance.loadAppOpenAd();
    }
    if (AdConfig.interstitialEnabled) {
      _instance.loadInterstitial();
    }
  }

  Future<void> loadAppOpenAd() async {
    if (!AdConfig.appOpenEnabled ||
        !_isInitialized ||
        _isAppOpenLoading ||
        _appOpenAd != null) {
      return;
    }
    _isAppOpenLoading = true;
    await AppOpenAd.load(
      adUnitId: AdConfig.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdService] AppOpen ad loaded successfully.');
          _appOpenAd = ad;
          _isAppOpenLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _appOpenAd = null;
              loadAppOpenAd();
            },
            onAdFailedToShowFullScreenContent: (a, err) {
              debugPrint('❌ [AdService] AppOpen failed to show: ${err.message}');
              a.dispose();
              _appOpenAd = null;
              loadAppOpenAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ [AdService] AppOpen failed to load: ${err.message} (code: ${err.code})');
          _isAppOpenLoading = false;
        },
      ),
    );
  }

  Future<void> showAppOpenAd() async {
    if (!AdConfig.appOpenEnabled || !_isInitialized || _appOpenAd == null) return;
    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_keyLastAppOpenTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cooldown = AdConfig.appOpenCooldownMinutes * 60;
    if (now - lastTs < cooldown) return;
    await prefs.setInt(_keyLastAppOpenTime, now);
    final ad = _appOpenAd!;
    _appOpenAd = null;
    await ad.show();
  }

  Future<void> loadInterstitial() async {
    if (!AdConfig.interstitialEnabled ||
        !_isInitialized ||
        _isInterstitialLoading ||
        _interstitialAd != null) {
      return;
    }
    _isInterstitialLoading = true;
    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdService] Interstitial ad loaded successfully.');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              debugPrint('❌ [AdService] Interstitial failed to show: ${err.message}');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialLoading = false;
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ [AdService] Interstitial failed to load: ${err.message} (code: ${err.code})');
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  Future<void> showInterstitial({VoidCallback? onClosed}) async {
    if (!AdConfig.interstitialEnabled || !_isInitialized || _interstitialAd == null) {
      onClosed?.call();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastTs = prefs.getInt(_keyLastInterstitialTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - lastTs < _minInterstitialIntervalSeconds) {
      onClosed?.call();
      return;
    }
    await prefs.setInt(_keyLastInterstitialTime, now);

    final ad = _interstitialAd!;
    _interstitialAd = null;
    final called = ValueNotifier(false);
    void safeClose() {
      if (!called.value) {
        called.value = true;
        onClosed?.call();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        loadInterstitial();
        safeClose();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        loadInterstitial();
        safeClose();
      },
    );
    await ad.show();
    Future.delayed(const Duration(seconds: 2), safeClose);
  }

  Future<void> preloadInterstitial() => loadInterstitial();
}
