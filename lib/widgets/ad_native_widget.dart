import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';
import '../services/ad_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// A beautifully styled Native Ad widget following HalalLens design standards.
/// Matches card radius (16px), theme typography, and includes a shimmer skeleton loader.
class AdNativeWidget extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final bool showBadge;

  const AdNativeWidget({
    super.key,
    this.margin,
    this.showBadge = true,
  });

  @override
  State<AdNativeWidget> createState() => _AdNativeWidgetState();
}

class _AdNativeWidgetState extends State<AdNativeWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  @override
  void initState() {
    super.initState();
    if (AdConfig.nativeEnabled && AdService.instance.isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  void _loadAd() {
    if (!mounted) return;
    final isDark = AppTheme.isDark(context);

    final primaryTextColor = isDark
        ? AppTheme.textPrimary
        : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;

    _nativeAd = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _nativeAdIsLoaded = false;
            });
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppTheme.primaryBlue,
          style: NativeTemplateFontStyle.bold,
          size: 13.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: primaryTextColor,
          style: NativeTemplateFontStyle.bold,
          size: 13.5,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          style: NativeTemplateFontStyle.normal,
          size: 11.5,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: secondaryTextColor,
          style: NativeTemplateFontStyle.normal,
          size: 10.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.nativeEnabled || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final isDark = AppTheme.isDark(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    // 1. Shimmer Skeleton Loading State
    if (!_nativeAdIsLoaded) {
      return Container(
        height: 96,
        width: double.infinity,
        margin: widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Placeholder Image Box
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.borderDark.withValues(alpha: 0.5)
                    : AppTheme.borderLight,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            // Placeholder Lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.borderDark.withValues(alpha: 0.6)
                          : AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.borderDark.withValues(alpha: 0.35)
                          : AppTheme.borderLight.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Loaded Native Ad Container
    return Container(
      height: 96,
      width: double.infinity,
      margin: widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
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
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: AdWidget(ad: _nativeAd!),
          ),
          if (widget.showBadge)
            Positioned(
              top: 6,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'SPONSORED',
                  style: AppFonts.primary(
                    context,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
