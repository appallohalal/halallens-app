import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../config/cms_config.dart';
import '../services/geo_ad_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Displays a sleek, professional Geo-Targeted Sponsored Local Banner when the user's
/// current GPS coordinates fall within the broadcast radius of an active campaign in Supabase.
/// Automatically hides itself (`SizedBox.shrink()`) when no campaign matches.
class GeoAdBannerWidget extends StatefulWidget {
  final EdgeInsetsGeometry? margin;

  const GeoAdBannerWidget({
    super.key,
    this.margin,
  });

  @override
  State<GeoAdBannerWidget> createState() => _GeoAdBannerWidgetState();
}

class _GeoAdBannerWidgetState extends State<GeoAdBannerWidget> {
  final PageController _pageController = PageController();
  Timer? _autoSlideTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GeoAdService.instance.refreshNearbyAds();
    });
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final ads = GeoAdService.instance.matchingAds.isNotEmpty
          ? GeoAdService.instance.matchingAds
          : GeoAdService.instance.allAds;
      if (ads.length <= 1 || !_pageController.hasClients) return;
      final nextPage = (_currentIndex + 1) % ads.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleTap(GeoAdCampaign ad) async {
    GeoAdService.instance.recordClick(ad);
    final urlStr = ad.targetUrl.trim();
    if (urlStr.isNotEmpty) {
      final uri = Uri.tryParse(urlStr);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GeoAdService>(
      builder: (context, geoService, _) {
        final isDark = AppTheme.isDark(context);

        // 1. If location services are turned off on the phone, display a smooth prompt alert
        if (geoService.isLocationDisabled) {
          return Container(
            margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    IconlyLight.location,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'location.services_disabled_title'.tr(),
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'location.services_disabled_desc'.tr(),
                        style: AppFonts.primary(
                          context,
                          color: AppTheme.getTextSecondary(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => geoService.openLocationSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'location.enable_btn'.tr(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final ads = geoService.matchingAds.isNotEmpty
            ? geoService.matchingAds
            : geoService.allAds;
        if (ads.isEmpty) {
          return const SizedBox.shrink();
        }

        final safeIndex = _currentIndex.clamp(0, ads.length - 1);
        final activeAd = ads[safeIndex];

        // Record impression once when displayed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          geoService.recordImpression(activeAd);
        });

        final noticeText = CmsConfig.geoAdsNoticeText;

        return Container(
          margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (noticeText.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, right: 4),
                  child: Row(
                    children: [
                      const Icon(
                        IconlyLight.location,
                        size: 15,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          noticeText,
                          style: AppFonts.primary(
                            context,
                            color: AppTheme.getTextPrimary(context),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SPONSORISÉ',
                          style: AppFonts.primary(
                            context,
                            color: AppTheme.primaryBlue,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(
                height: 178,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: ads.length,
                  onPageChanged: (idx) {
                    setState(() => _currentIndex = idx);
                    geoService.recordImpression(ads[idx]);
                  },
                  itemBuilder: (context, index) {
                    final ad = ads[index];
                    return _buildAdCard(context, ad, isDark);
                  },
                ),
              ),
              if (ads.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(ads.length, (i) {
                    final isSelected = i == safeIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 5,
                      width: isSelected ? 18 : 5,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.getTextMuted(context)
                                .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdCard(BuildContext context, GeoAdCampaign ad, bool isDark) {
    final distanceLabel = ad.distanceKm > 0.0
        ? (ad.distanceKm < 1.0
            ? 'general.distance_m'.tr(args: ['${(ad.distanceKm * 1000).round()}'])
            : 'general.distance_km'.tr(args: [ad.distanceKm.toStringAsFixed(1)]))
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppTheme.getBorderColor(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(ad),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Banner Image
              Image.network(
                ad.bannerImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: isDark
                        ? const Color(0xFF161B22)
                        : const Color(0xFFF1F5F9),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    ),
                  );
                },
                errorBuilder: (ctx, err, stack) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF066D2E),
                        Color(0xFF0F172A),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    IconlyBold.bag_2,
                    color: Colors.white.withValues(alpha: 0.25),
                    size: 48,
                  ),
                ),
              ),

              // 2. Multi-Stop Rich Scrim Gradient for crisp text legibility
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.7, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.65),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),

              // 3. Top Bar: Verified Partner Badge & Distance Pill
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Glassmorphic Sponsored Chip
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                IconlyBold.shield_done,
                                color: Color(0xFF34D399),
                                size: 12,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                ad.partnerBadge.trim().isNotEmpty
                                    ? ad.partnerBadge.trim()
                                    : 'general.featured_partner'.tr(),
                                style: AppFonts.primary(
                                  context,
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Distance Pill
                    if (distanceLabel != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  IconlyBold.location,
                                  color: Colors.white,
                                  size: 11.5,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  distanceLabel,
                                  style: AppFonts.primary(
                                    context,
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Bottom Content: Sponsor Info, Offer Headline, and Action Button
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  ad.sponsorName.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.primary(
                                    context,
                                    color: const Color(0xFF6EE7B7),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              if (ad.locationName.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    ad.locationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.primary(
                                      context,
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ad.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.primary(
                              context,
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // CTA Pill Button
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'general.visit'.tr(),
                            style: AppFonts.primary(
                              context,
                              color: const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            IconlyBold.arrow_right_2,
                            color: AppTheme.primaryBlue,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
