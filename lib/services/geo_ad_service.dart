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
  final String bannerImageUrl;
  final String targetUrl;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String locationName;
  final double distanceKm;
  final int impressionCount;
  final int clickCount;

  const GeoAdCampaign({
    required this.id,
    required this.title,
    required this.sponsorName,
    required this.bannerImageUrl,
    required this.targetUrl,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.locationName,
    required this.distanceKm,
    this.impressionCount = 0,
    this.clickCount = 0,
  });

  factory GeoAdCampaign.fromMap(Map<String, dynamic> map, {double distanceKm = 0.0}) {
    return GeoAdCampaign(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      sponsorName: (map['sponsorName'] ?? map['sponsor_name'] ?? '').toString(),
      bannerImageUrl:
          (map['bannerImageUrl'] ?? map['banner_image_url'] ?? '').toString(),
      targetUrl: (map['targetUrl'] ?? map['target_url'] ?? '').toString(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusKm:
          (map['radiusKm'] ?? map['radius_km'] as num?)?.toDouble() ?? 15.0,
      locationName:
          (map['locationName'] ?? map['location_name'] ?? '').toString(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? distanceKm,
      impressionCount: (map['impression_count'] as num?)?.toInt() ?? 0,
      clickCount: (map['click_count'] as num?)?.toInt() ?? 0,
    );
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
  double? _userLat;
  double? _userLng;
  bool _isLoading = false;
  bool _isLocationDisabled = false;
  bool _isPermissionDenied = false;
  final Set<String> _recordedImpressions = {};

  List<GeoAdCampaign> get matchingAds => _matchingAds;
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
      // 1. Obtain current GPS coordinates from native OS location provider
      final coords = await _getUserCoordinates();
      if (coords == null) {
        _matchingAds = [];
        _isLoading = false;
        notifyListeners();
        return;
      }

      _userLat = coords.$1;
      _userLng = coords.$2;

      // 2. Fetch active campaigns directly from Supabase REST (fast & resilient)
      // with fallback to Backend API /api/v1/ads
      final campaigns = await _fetchAndFilterFromSupabase(_userLat!, _userLng!);
      _matchingAds = campaigns;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ GeoAdService refresh error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<(double, double)?> _getUserCoordinates() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _locationChannel
            .invokeMapMethod<String, dynamic>('getCurrentLocation')
            .timeout(const Duration(seconds: 6), onTimeout: () => null);

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
      ).timeout(const Duration(seconds: 5));

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

