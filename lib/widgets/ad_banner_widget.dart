import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import '../services/ad_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// A polished AdMob Banner widget following HalalLens design standards.
/// Supports both sticky bottom docking and floating rounded card presentation.
class AdBannerWidget extends StatefulWidget {
  final bool isCard;
  final bool showAdBadge;
  final EdgeInsetsGeometry? margin;

  const AdBannerWidget({
    super.key,
    this.isCard = false,
    this.showAdBadge = true,
    this.margin,
  });

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
    if (AdConfig.bannerEnabled && AdService.instance.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  Future<void> _loadAd() async {
    if (!mounted || !AdConfig.bannerEnabled) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final adWidth = widget.isCard ? (width - 48).clamp(280, width) : width;
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth);
    final size = adSize ?? AdSize.banner;

    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad loadedAd) {
          debugPrint('✅ [AdBanner] Banner ad loaded successfully.');
          if (mounted) {
            setState(() {
              _ad = loadedAd as BannerAd;
              _pendingAd = null;
              _loaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad failedAd, LoadAdError err) {
          debugPrint('❌ [AdBanner] Failed to load banner: ${err.message} (code: ${err.code})');
          failedAd.dispose();
          if (mounted) {
            setState(() {
              _pendingAd = null;
              _loaded = false;
            });
          }
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
    if (!AdConfig.bannerEnabled || !_loaded || _ad == null) {
      return const SizedBox.shrink();
    }

    final ad = _ad!;
    final isDark = AppTheme.isDark(context);

    // 1. Floating Card Style (e.g. for feed / in-page placements)
    if (widget.isCard) {
      return Container(
        margin: widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.getBorderColor(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.showAdBadge) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildAdBadge(context),
                ],
              ),
              const SizedBox(height: 4),
            ],
            AnimatedOpacity(
              opacity: _loaded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: KeyedSubtree(
                  key: ObjectKey(ad),
                  child: AdWidget(ad: ad),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Sticky Bottom Docked Style
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        border: Border(
          top: BorderSide(
            color: AppTheme.getBorderColor(context).withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showAdBadge)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildAdBadge(context),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.only(bottom: 4, top: 2),
              alignment: Alignment.center,
              width: double.infinity,
              height: ad.size.height.toDouble() + 6,
              child: AnimatedOpacity(
                opacity: _loaded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ObjectKey(ad),
                  child: AdWidget(ad: ad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        'AD',
        style: AppFonts.primary(
          context,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
