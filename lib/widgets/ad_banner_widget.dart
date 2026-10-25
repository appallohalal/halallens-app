import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _ad;
  BannerAd? _pendingAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdConfig.adsEnabled && AdService.instance.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted || !AdConfig.adsEnabled) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    final size = adSize ?? AdSize.banner;
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad loadedAd) {
          if (mounted) {
            setState(() {
              _ad = loadedAd as BannerAd;
              _pendingAd = null;
              _loaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad failedAd, LoadAdError err) {
          failedAd.dispose();
          if (mounted) setState(() => _pendingAd = null);
        },
      ),
    );
    if (!mounted) return;
    _pendingAd = ad;
    await ad.load();
    if (!mounted && _ad != ad) {
      ad.dispose();
      _pendingAd = null;
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    _pendingAd?.dispose();
    _ad = null;
    _pendingAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.adsEnabled || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }
    final ad = _ad!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.getBorderColor(context).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          width: double.infinity,
          height: ad.size.height.toDouble() + 8,
          child: KeyedSubtree(
            key: ObjectKey(ad),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
