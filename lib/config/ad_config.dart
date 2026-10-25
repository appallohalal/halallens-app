import 'package:flutter/foundation.dart';

class AdConfig {
  AdConfig._();

  static const bool testAdsEnabled = false;

  static const String testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String testIosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const String testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String testAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testAndroidAppOpenId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String testIosAppOpenId =
      'ca-app-pub-3940256099942544/5575463023';
  static const String testAndroidNativeId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testIosNativeId =
      'ca-app-pub-3940256099942544/3986624511';

  static const bool productionAdsEnabled = false;

  // Replace with your AdMob IDs before release
  static const String productionAndroidAppId = 'ca-app-pub-XXXXX~YYYYY';
  static const String productionIosAppId = 'ca-app-pub-XXXXX~YYYYY';
  static const String productionAndroidBannerId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionIosBannerId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionAndroidInterstitialId =
      'ca-app-pub-XXXXX/YYYYY';
  static const String productionIosInterstitialId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionAndroidAppOpenId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionIosAppOpenId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionAndroidNativeId = 'ca-app-pub-XXXXX/YYYYY';
  static const String productionIosNativeId = 'ca-app-pub-XXXXX/YYYYY';

  static bool get adsEnabled => productionAdsEnabled;

  static String get androidAppId => productionAndroidAppId;
  static String get iosAppId => productionIosAppId;

  static String get bannerAdUnitId =>
      defaultTargetPlatform == TargetPlatform.android
      ? productionAndroidBannerId
      : productionIosBannerId;

  static String get interstitialAdUnitId =>
      defaultTargetPlatform == TargetPlatform.android
      ? productionAndroidInterstitialId
      : productionIosInterstitialId;

  static String get appOpenAdUnitId =>
      defaultTargetPlatform == TargetPlatform.android
      ? productionAndroidAppOpenId
      : productionIosAppOpenId;

  static String get nativeAdUnitId =>
      defaultTargetPlatform == TargetPlatform.android
      ? productionAndroidNativeId
      : productionIosNativeId;
}
