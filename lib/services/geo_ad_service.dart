import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class GeoAdCampaign {
  final String id;
  final String title;
  final String sponsorName;
  final String category;
  final String bannerImageUrl;
  final String targetUrl;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String locationName;
  final String partnerBadge;
  final String certifyingBody;
  final double distanceKm;
  final int impressionCount;
  final int clickCount;

  const GeoAdCampaign({
    required this.id,
    required this.title,
    required this.sponsorName,
    this.category = 'restaurant',
    required this.bannerImageUrl,
    required this.targetUrl,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.locationName,
    this.partnerBadge = 'PARTENAIRE RECOMMANDÉ',
    this.certifyingBody = 'AVS',
    required this.distanceKm,
    this.impressionCount = 0,
    this.clickCount = 0,
  });

  factory GeoAdCampaign.fromMap(Map<String, dynamic> map, {double distanceKm = 0.0}) {
    return GeoAdCampaign(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      sponsorName: (map['sponsorName'] ?? map['sponsor_name'] ?? '').toString(),
      category: (map['category'] ?? 'restaurant').toString(),
      bannerImageUrl:
          (map['bannerImageUrl'] ?? map['banner_image_url'] ?? '').toString(),
      targetUrl: (map['targetUrl'] ?? map['target_url'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusKm:
          (map['radiusKm'] ?? map['radius_km'] as num?)?.toDouble() ?? 15.0,
      locationName: (map['locationName'] ?? map['location_name']) != null &&
              (map['locationName'] ?? map['location_name'])
                  .toString()
                  .trim()
                  .isNotEmpty
          ? (map['locationName'] ?? map['location_name']).toString().trim()
          : _resolveLocationName(
              (map['latitude'] as num?)?.toDouble() ?? 0.0,
              (map['longitude'] as num?)?.toDouble() ?? 0.0,
              (map['title'] ?? '').toString(),
              (map['sponsorName'] ?? map['sponsor_name'] ?? '').toString(),
            ),
      partnerBadge: (map['partner_badge'] ?? map['partnerBadge'] ?? 'PARTENAIRE RECOMMANDÉ').toString(),
      certifyingBody: (map['certifying_body'] ?? map['certifyingBody'] ?? '').toString(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? distanceKm,
      impressionCount:
          (map['impression_count'] ?? map['impressions'] as num?)?.toInt() ?? 0,
      clickCount:
          (map['click_count'] ?? map['clicks'] as num?)?.toInt() ?? 0,
    );
  }

  static String _resolveLocationName(
    double lat,
    double lng,
    String title,
    String sponsor,
  ) {
    final lower = '$title $sponsor'.toLowerCase();
    if (lower.contains('niort') ||
        (lat >= 46.25 && lat <= 46.40 && lng >= -0.55 && lng <= -0.35)) {
      return 'Niort, France';
    }
    if (lower.contains('rochelle') ||
        (lat >= 46.10 && lat <= 46.22 && lng >= -1.25 && lng <= -1.10)) {
      return 'La Rochelle, France';
    }
    if (lower.contains('poitiers') ||
        (lat >= 46.50 && lat <= 46.65 && lng >= 0.25 && lng <= 0.45)) {
      return 'Poitiers, France';
    }
    if (lower.contains('paris') ||
        (lat >= 48.75 && lat <= 48.95 && lng >= 2.15 && lng <= 2.50)) {
      return 'Paris, France';
    }
    if (lower.contains('lyon') ||
        (lat >= 45.65 && lat <= 45.85 && lng >= 4.75 && lng <= 4.95)) {
      return 'Lyon, France';
    }
    if (lower.contains('bordeaux') ||
        (lat >= 44.75 && lat <= 44.95 && lng >= -0.65 && lng <= -0.45)) {
      return 'Bordeaux, France';
    }
    if (lat >= 35.0 && lat <= 60.0 && lng >= -10.0 && lng <= 30.0) {
      return 'France / Europe';
    }
    return 'Partenaire Local';
  }
}

/// Geo-Targeted Sponsored Banner Service.
/// 1. Fetches the user's current GPS coordinates (with OS permission).
/// 2. Queries active campaigns from Supabase (`geo_ads` table) / Backend API.
/// 3. Calculates exact distance (Haversine) and displays matching campaigns within the broadcast radius.
class GeoAdService extends ChangeNotifier {
  GeoAdService._();
  static final GeoAdService instance = GeoAdService._();

  static const MethodChannel _locationChannel =
      MethodChannel('com.allohalal.app/location');

  List<GeoAdCampaign> _matchingAds = [];
  List<GeoAdCampaign> _allAds = [];
  double? _userLat;
  double? _userLng;
  bool _isLoading = false;
  bool _isLocationDisabled = false;
  bool _isPermissionDenied = false;
  final Set<String> _recordedImpressions = {};
  List<String> _categories = [];

  List<GeoAdCampaign> get matchingAds => _matchingAds;
  List<GeoAdCampaign> get allAds => _allAds.isNotEmpty ? _allAds : _matchingAds;
  List<String> get categories => _categories;
  GeoAdCampaign? get primaryAd =>
      _matchingAds.isNotEmpty ? _matchingAds.first : null;
  bool get hasMatchingAd => _matchingAds.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isLocationDisabled => _isLocationDisabled;
  bool get isPermissionDenied => _isPermissionDenied;
  double? get userLat => _userLat;
  double? get userLng => _userLng;

  /// Checks if device location service (GPS) is turned on
  Future<bool> isLocationServiceEnabled() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final enabled = await _locationChannel
            .invokeMethod<bool>('isLocationServiceEnabled');
        return enabled ?? true;
      } catch (_) {}
    }
    return true;
  }

  /// Opens the native device location settings screen
  Future<bool> openLocationSettings() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final ok =
            await _locationChannel.invokeMethod<bool>('openLocationSettings');
        return ok ?? false;
      } catch (_) {}
    }
    return false;
  }

  /// Opens the native app settings screen (for permission recovery)
  Future<bool> openAppSettings() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final ok = await _locationChannel.invokeMethod<bool>('openAppSettings');
        return ok ?? false;
      } catch (_) {}
    }
    return false;
  }

  /// Called when the app opens or when scanning starts/completes.
  Future<void> refreshNearbyAds() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      // 1. Obtain current GPS coordinates from native OS location provider (Android & iOS)
      final coords = await _getUserCoordinates();
      if (coords != null) {
        _userLat = coords.$1;
        _userLng = coords.$2;

        // Fetch active campaigns matching user location & broadcast radius
        final campaigns = await _fetchAndFilterFromSupabase(_userLat!, _userLng!);
        if (campaigns.isNotEmpty) {
          _matchingAds = campaigns;
          return;
        }
      }

      // 2. Fallback: If GPS is unavailable/permission pending or no immediate radius cutoff,
      // load active partner campaigns so advertisements always render seamlessly
      await fetchAllPartnerBusinesses();
      _matchingAds = _allAds;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ GeoAdService refresh error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches all active partner businesses regardless of strict radius cutoff.
  /// Computes real distances relative to the user position if GPS is available.
  Future<List<GeoAdCampaign>> fetchAllPartnerBusinesses() async {
    try {
      // Refresh coordinates if available
      if (_userLat == null || _userLng == null) {
        final coords = await _getUserCoordinates();
        if (coords != null) {
          _userLat = coords.$1;
          _userLng = coords.$2;
        }
      }

      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/geo_ads?is_active=eq.true&select=*',
      );
      final response = await http.get(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
        final List<GeoAdCampaign> all = [];

        for (final item in rows) {
          if (item is! Map<String, dynamic>) continue;
          final isActive = item['is_active'] as bool? ?? true;
          if (!isActive) continue;

          final adLat = (item['latitude'] as num?)?.toDouble() ?? 0.0;
          final adLng = (item['longitude'] as num?)?.toDouble() ?? 0.0;

          double dist = 0.0;
          if (_userLat != null && _userLng != null && adLat != 0.0 && adLng != 0.0) {
            dist = _calculateDistanceKm(_userLat!, _userLng!, adLat, adLng);
          }

          all.add(GeoAdCampaign.fromMap(item, distanceKm: dist));
        }

        if (_userLat != null && _userLng != null) {
          all.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        }

        if (kDebugMode) {
          debugPrint('ℹ️ GeoAdService: Loaded ${all.length} live ads from Supabase');
        }

        if (all.isNotEmpty) {
          _allAds = all;
          notifyListeners();
          return all;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ℹ️ Error fetching all partner businesses: $e');
    }

    // Secondary fallback: query Next.js backend ads endpoint
    try {
      final backendUri = Uri.parse(
        _userLat != null && _userLng != null
            ? '${AppConfig.backendBaseUrl}/ads?lat=$_userLat&lng=$_userLng'
            : '${AppConfig.backendBaseUrl}/ads',
      );
      final backendRes =
          await http.get(backendUri).timeout(const Duration(seconds: 4));
      if (backendRes.statusCode == 200) {
        final data = jsonDecode(backendRes.body) as Map<String, dynamic>;
        final List<dynamic> list = (data['ads'] as List<dynamic>?) ?? [];
        final List<GeoAdCampaign> backendAds = list
            .whereType<Map<String, dynamic>>()
            .map((m) => GeoAdCampaign.fromMap(m))
            .toList();

        if (backendAds.isNotEmpty) {
          _allAds = backendAds;
          notifyListeners();
          return backendAds;
        }
      }
    } catch (_) {}

    // If matchingAds has real items from refreshNearbyAds, use those
    if (_matchingAds.isNotEmpty) {
      _allAds = _matchingAds;
      return _matchingAds;
    }

    // Zero static/demo data - return empty list if server has no ads
    _allAds = [];
    notifyListeners();
    return [];
  }

  /// Fetches the dynamically managed partner categories from Supabase / Backend API
  Future<List<String>> fetchCategories() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/partner_categories?is_active=eq.true&select=name&order=display_order.asc',
      );
      final response = await http.get(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
        final List<String> list = [];
        for (final item in rows) {
          if (item is Map<String, dynamic> && item['name'] != null) {
            final name = item['name'].toString().trim();
            if (name.isNotEmpty && !list.contains(name)) {
              list.add(name);
            }
          }
        }
        if (list.isNotEmpty) {
          _categories = list;
          notifyListeners();
          return list;
        }
      }
    } catch (_) {}

    // Fallback: collect categories from loaded ads
    final Set<String> derived = {};
    for (final ad in allAds) {
      final c = ad.category.trim();
      if (c.isNotEmpty) derived.add(c);
    }
    if (derived.isNotEmpty) {
      _categories = derived.toList();
      notifyListeners();
      return _categories;
    }

    return _categories;
  }

  Future<(double, double)?> _getUserCoordinates() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final res = await _locationChannel
            .invokeMapMethod<String, dynamic>('getCurrentLocation')
            .timeout(const Duration(seconds: 8), onTimeout: () => null);

        if (res != null) {
          final status = res['status']?.toString();
          if (status == 'LOCATION_DISABLED') {
            _isLocationDisabled = true;
            _isPermissionDenied = false;
            notifyListeners();
            return null;
          } else if (status == 'PERMISSION_DENIED') {
            _isPermissionDenied = true;
            _isLocationDisabled = false;
            notifyListeners();
            return null;
          }

          if (res['latitude'] != null && res['longitude'] != null) {
            _isLocationDisabled = false;
            _isPermissionDenied = false;
            final lat = (res['latitude'] as num).toDouble();
            final lng = (res['longitude'] as num).toDouble();
            return (lat, lng);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('ℹ️ Native GPS check info: $e');
      }
    }
    return null;
  }

  Future<List<GeoAdCampaign>> _fetchAndFilterFromSupabase(
    double userLat,
    double userLng,
  ) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/geo_ads?is_active=eq.true&select=*',
      );
      final response = await http.get(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
        final List<GeoAdCampaign> matches = [];

        for (final item in rows) {
          if (item is! Map<String, dynamic>) continue;
          final isActive = item['is_active'] as bool? ?? true;
          if (!isActive) continue;

          final adLat = (item['latitude'] as num?)?.toDouble();
          final adLng = (item['longitude'] as num?)?.toDouble();
          final radiusKm = (item['radius_km'] as num?)?.toDouble() ?? 15.0;

          if (adLat == null || adLng == null) continue;

          final distanceKm = _calculateDistanceKm(userLat, userLng, adLat, adLng);
          if (distanceKm <= radiusKm) {
            matches.add(GeoAdCampaign.fromMap(item, distanceKm: distanceKm));
          }
        }

        matches.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return matches;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ℹ️ Supabase geo_ads query fallback: $e');
    }

    // Fallback to Next.js backend endpoint
    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/ads?lat=$userLat&lng=$userLng',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = (data['ads'] as List<dynamic>?) ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((m) => GeoAdCampaign.fromMap(m))
            .toList();
      }
    } catch (_) {}

    return [];
  }

  /// Haversine formula to compute distance in kilometers between two GPS points.
  static double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return ((earthRadiusKm * c) * 100).roundToDouble() / 100;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Increment impression count in Supabase once per session per ad.
  Future<void> recordImpression(GeoAdCampaign ad) async {
    if (ad.id.isEmpty || _recordedImpressions.contains(ad.id)) return;
    _recordedImpressions.add(ad.id);

    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/geo_ads?id=eq.${ad.id}',
      );
      await http.patch(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'impression_count': ad.impressionCount + 1,
        }),
      );
    } catch (_) {}
  }

  /// Increment click count in Supabase when user taps the banner.
  Future<void> recordClick(GeoAdCampaign ad) async {
    if (ad.id.isEmpty) return;
    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/geo_ads?id=eq.${ad.id}',
      );
      await http.patch(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'click_count': ad.clickCount + 1,
        }),
      );
    } catch (_) {}
  }
}

