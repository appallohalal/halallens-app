import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/geo_ad_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Screen displaying the local directory of Halal partner businesses and geo-targeted advertisements.
/// Fully localized across all 14 languages without missing keys.
class NearbyBusinessesScreen extends StatefulWidget {
  const NearbyBusinessesScreen({super.key});

  @override
  State<NearbyBusinessesScreen> createState() => _NearbyBusinessesScreenState();
}

class _NearbyBusinessesScreenState extends State<NearbyBusinessesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isLoadingInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingInitial = true);
    await GeoAdService.instance.refreshNearbyAds();
    await GeoAdService.instance.fetchAllPartnerBusinesses();
    await GeoAdService.instance.fetchCategories();
    if (mounted) {
      setState(() => _isLoadingInitial = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<GeoAdCampaign> _filterBusinesses(List<GeoAdCampaign> list) {
    return list.where((ad) {
      // Category filter
      if (_selectedCategory != 'all') {
        final sel = _selectedCategory.toLowerCase().trim();
        final adCat = ad.category.toLowerCase().trim();

        // Exact match or normalized matching
        final bool isMatch = adCat == sel ||
            '${adCat}s' == sel ||
            adCat == '${sel}s' ||
            (sel.startsWith('resto') && adCat.startsWith('resto')) ||
            ((sel.startsWith('bouch') || sel.contains('butcher')) &&
                (adCat.startsWith('bouch') || adCat.contains('butcher'))) ||
            ((sel.startsWith('épic') || sel.startsWith('epic') || sel.contains('grocer')) &&
                (adCat.startsWith('épic') || adCat.startsWith('epic') || adCat.contains('grocer'))) ||
            ((sel.startsWith('boulang') || sel.contains('baker')) &&
                (adCat.startsWith('boulang') || adCat.contains('baker')));

        if (!isMatch) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchTitle = ad.title.toLowerCase().contains(q);
        final matchSponsor = ad.sponsorName.toLowerCase().contains(q);
        final matchLocation = ad.locationName.toLowerCase().contains(q);
        final matchCategory = ad.category.toLowerCase().contains(q);
        final matchCertifier = ad.certifyingBody.toLowerCase().contains(q);
        if (!matchTitle && !matchSponsor && !matchLocation && !matchCategory && !matchCertifier) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _openDirections(GeoAdCampaign ad) async {
    final lat = ad.latitude;
    final lng = ad.longitude;
    final query = (lat != 0.0 && lng != 0.0)
        ? '$lat,$lng'
        : Uri.encodeComponent('${ad.sponsorName} ${ad.locationName}');

    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$query';
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTargetUrl(GeoAdCampaign ad) async {
    GeoAdService.instance.recordClick(ad);
    final urlStr = ad.targetUrl.trim();
    if (urlStr.isNotEmpty) {
      final uri = Uri.tryParse(urlStr);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    _openDirections(ad);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            IconlyLight.arrow_left,
            color: AppTheme.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'settings.nearby_businesses_title'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppTheme.getTextPrimary(context),
            ),
            tooltip: 'directory.refresh'.tr(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<GeoAdService>(
        builder: (context, geoService, _) {
          final allBusinesses = geoService.allAds;
          final filtered = _filterBusinesses(allBusinesses);

          return Column(
            children: [
              // 1. GPS Status banner if disabled
              if (geoService.isLocationDisabled || geoService.isPermissionDenied)
                _buildLocationPermissionBanner(context, geoService),

              // 2. Search and Category filters
              _buildSearchAndFilters(context, geoService),

              // 3. Main Directory List
              Expanded(
                child: _isLoadingInitial
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue,
                        ),
                      )
                    : _buildListView(context, filtered),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationPermissionBanner(
    BuildContext context,
    GeoAdService geoService,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? const Color(0xFF1E293B)
            : const Color(0xFFE6F4EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconlyBold.location,
              size: 18,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              geoService.isLocationDisabled
                  ? 'directory.gps_disabled'.tr()
                  : 'directory.gps_denied'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 12,
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (geoService.isLocationDisabled) {
                geoService.openLocationSettings();
              } else {
                geoService.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'directory.activate'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, GeoAdService geoService) {
    final categories = <Map<String, String>>[
      {'id': 'all', 'label': 'directory.all'.tr()},
    ];

    final knownIds = <String>{'all'};

    // 1. Add categories dynamically from Supabase / Admin back-office via GeoAdService
    for (final c in geoService.categories) {
      final trimmed = c.trim();
      final id = trimmed.toLowerCase();
      if (trimmed.isNotEmpty && !knownIds.contains(id)) {
        knownIds.add(id);
        categories.add({
          'id': id,
          'label': _getCategoryLabel(trimmed),
        });
      }
    }

    // 2. Also add any active category from loaded ads in case an ad has a newly created category
    for (final ad in geoService.allAds) {
      final c = ad.category.trim();
      final id = c.toLowerCase();
      if (c.isNotEmpty && !knownIds.contains(id)) {
        knownIds.add(id);
        categories.add({
          'id': id,
          'label': _getCategoryLabel(c),
        });
      }
    }

    // 3. Fallback only if completely offline and nothing was retrieved
    if (categories.length == 1) {
      for (final fc in ['Restaurants', 'Boucheries', 'Épiceries', 'Boulangeries']) {
        categories.add({
          'id': fc.toLowerCase(),
          'label': _getCategoryLabel(fc),
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar matching the App Card Design
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.getBorderColor(context),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: AppFonts.primary(
                context,
                color: AppTheme.getTextPrimary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'directory.search_hint'.tr(),
                hintStyle: AppFonts.primary(
                  context,
                  color: AppTheme.getTextMuted(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  IconlyLight.search,
                  size: 20,
                  color: AppTheme.primaryBlue,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Category Filter Chips (Text Only, No Icons)
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final isSelected = _selectedCategory.toLowerCase() == cat['id']!.toLowerCase();

              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat['id']!),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : AppTheme.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat['label']!,
                      style: AppFonts.primary(
                        context,
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.getTextPrimary(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<GeoAdCampaign> businesses,
  ) {
    if (businesses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  IconlyLight.location,
                  size: 36,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'directory.no_results'.tr(),
                style: AppFonts.primary(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'directory.no_results_desc'.tr(),
                textAlign: TextAlign.center,
                style: AppFonts.primary(
                  context,
                  fontSize: 14,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('directory.refresh'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: const BorderSide(color: AppTheme.primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          final ad = businesses[index];
          return _buildBusinessCard(context, ad);
        },
      ),
    );
  }

  Widget _buildBusinessCard(
    BuildContext context,
    GeoAdCampaign ad,
  ) {
    final distanceLabel = ad.distanceKm > 0
        ? (ad.distanceKm < 1.0
            ? 'general.distance_m'.tr(args: ['${(ad.distanceKm * 1000).round()}'])
            : 'general.distance_km'.tr(args: [ad.distanceKm.toStringAsFixed(1)]))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTargetUrl(ad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Banner
            SizedBox(
              height: 145,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ad.bannerImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: const Icon(
                        IconlyLight.bag_2,
                        size: 40,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),

                  // Top badges
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: Color(0xFF34D399),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                ad.partnerBadge.trim().isNotEmpty
                                    ? ad.partnerBadge.trim()
                                    : 'directory.recommended_partner'.tr(),
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (distanceLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  IconlyLight.location,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  distanceLabel,
                                  style: AppFonts.primary(
                                    context,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
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

            // Card Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ad.sponsorName,
                          style: AppFonts.primary(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                      ),
                      if (ad.category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _getCategoryLabel(ad.category),
                            style: AppFonts.primary(
                              context,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (ad.locationName.isNotEmpty) ...[
                        const Icon(
                          IconlyLight.location,
                          size: 14,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          ad.locationName,
                          style: AppFonts.primary(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.title,
                    style: AppFonts.primary(
                      context,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.getTextSecondary(context),
                      height: 1.35,
                    ),
                  ),
                  if (ad.certifyingBody.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF088839).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF088839).withValues(alpha: 0.25),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 14,
                            color: Color(0xFF088839),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'directory.certified_by'.tr(args: [ad.certifyingBody.trim()]),
                            style: AppFonts.primary(
                              context,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF066D2E),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(ad),
                          icon: const Icon(
                            IconlyLight.location,
                            size: 16,
                            color: AppTheme.primaryBlue,
                          ),
                          label: Text(
                            'directory.directions'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: AppTheme.primaryBlue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openTargetUrl(ad),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            'directory.visit_offer'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String cat) {
    final lower = cat.toLowerCase().trim();
    if (lower == 'butcher' || lower == 'boucherie' || lower == 'boucheries') {
      return 'directory.butcher'.tr();
    }
    if (lower == 'restaurant' || lower == 'restaurants') {
      return 'directory.restaurant'.tr();
    }
    if (lower == 'grocery' || lower == 'épicerie' || lower == 'épiceries' || lower == 'epicerie' || lower == 'epiceries') {
      return 'directory.grocery'.tr();
    }
    if (lower == 'bakery' || lower == 'boulangerie' || lower == 'boulangeries') {
      return 'directory.bakery'.tr();
    }
    return cat.isNotEmpty ? cat : 'directory.all'.tr();
  }
}
