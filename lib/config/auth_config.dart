import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Server-driven Authentication Configuration (Feature Toggle).
/// Controls whether mobile user registration is mandatory or optional (V1 default: optional).
/// Follows the identical architectural pattern as GroqConfig and AdConfig.
class AuthConfig {
  AuthConfig._();

  static const String _prefKeyCachedAuthConfig = 'cached_auth_remote_config';

  static bool _forceUserAuth = false;
  static bool _allowGuestScan = true;
  static bool _enableContributions = true;
  static bool _requireEmailVerification = false;
  static DateTime? _lastSyncedAt;

  // Contribution Presets & Tiers Configuration
  static List<double> _contributionPresets = [1.0, 3.0, 5.0, 10.0, 15.0];
  static double _defaultContributionAmount = 5.0;
  static double _minContributionAmount = 1.0;
  static double _maxContributionAmount = 50.0;
  static String _contributionCurrency = 'EUR';
  static double _coffeeMaxAmount = 2.0;
  static double _serverMaxAmount = 4.0;
  static double _growthMaxAmount = 9.0;

  // Humanitarian Commitment & Solidarity
  static bool _enableHumanitarianCommitment = true;
  static String _humanitarianTitle = 'Humanitarian Commitment & Solidarity';
  static String _humanitarianBadge = 'Charity Redistribution Partner';
  static String _humanitarianCharityShare = '20% Redistributed to Charity';
  static String _humanitarianText =
      'Allo Halal is driven by ethical and community values. In the spirit of Islamic solidarity, a dedicated portion of every free-will contribution is redirected towards verified humanitarian partners to provide emergency food aid and clean water for vulnerable families worldwide.';
  static String _humanitarianOrganizationName = 'Global Halal Emergency Food Relief';
  static String _humanitarianLearnMoreUrl = 'https://allohalal.fr/humanitarian';

  // Stripe Payment Gateway Configuration
  static bool _enableStripe = true;
  static String _stripeMode = 'test';
  static String _stripePublishableKey =
      'pk_test_51P9nVoRrokKxR1k7GYpiCd7B9ZVwmR7MBuYx28GmKrRsaOPUHmSMSIESH62ZVDwx6IFlN8xSz7br9cg0LzfLVbrK00uFBuBNzr';
  static String _stripeSecretKey = '';
  static String _stripeCurrency = 'EUR';

  // ===========================================================================
  // Public Dynamic Getters (Used throughout the App & Services)
  // ===========================================================================

  /// When true, user account creation / login is mandatory before scanning.
  /// When false (V1 default), users can freely scan anonymously as guests.
  static bool get isForceUserAuth => _forceUserAuth;

  /// True if guest scanning is allowed without registration.
  static bool get allowGuestScan => _allowGuestScan && !_forceUserAuth;

  /// True if community product submissions and contributions are active.
  static bool get isContributionsEnabled => _enableContributions;

  /// True if registered users must verify their email address.
  static bool get requireEmailVerification => _requireEmailVerification;

  /// Configured preset amounts for free-will contribution (e.g. 1€, 3€, 5€, 10€, 15€)
  static List<double> get contributionPresets => _contributionPresets;

  /// Default preselected contribution amount (e.g. 5€)
  static double get defaultContributionAmount => _defaultContributionAmount;

  /// Minimum slider amount
  static double get minContributionAmount => _minContributionAmount;

  /// Maximum slider amount
  static double get maxContributionAmount => _maxContributionAmount;

  /// Contribution currency symbol or code (e.g. EUR, USD)
  static String get contributionCurrency => _contributionCurrency;

  /// Tier ceilings
  static double get coffeeMaxAmount => _coffeeMaxAmount;
  static double get serverMaxAmount => _serverMaxAmount;
  static double get growthMaxAmount => _growthMaxAmount;

  /// Humanitarian commitment display toggle
  static bool get isHumanitarianCommitmentEnabled => _enableHumanitarianCommitment;

  /// Humanitarian commitment title
  static String get humanitarianTitle => _humanitarianTitle;

  /// Humanitarian badge / tagline
  static String get humanitarianBadge => _humanitarianBadge;

  /// Charity redistribution percentage / share
  static String get humanitarianCharityShare => _humanitarianCharityShare;

  /// Humanitarian commitment purpose & statement
  static String get humanitarianText => _humanitarianText;

  /// Partner charity organization name
  static String get humanitarianOrganizationName => _humanitarianOrganizationName;

  /// Learn more URL for humanitarian program
  static String get humanitarianLearnMoreUrl => _humanitarianLearnMoreUrl;

  /// Whether Stripe payment gateway is enabled
  static bool get isStripeEnabled => _enableStripe;

  /// Stripe environment ('test' or 'live')
  static String get stripeMode => _stripeMode;

  /// Stripe Publishable Key for mobile integration
  static String get stripePublishableKey => _stripePublishableKey;

  /// Stripe Secret Key for direct mobile test mode checkout creation
  static String get stripeSecretKey => _stripeSecretKey;

  /// Stripe payment currency (e.g. 'EUR')
  static String get stripeCurrency => _stripeCurrency;

  /// Timestamp of the last remote sync
  static DateTime? get lastSyncedAt => _lastSyncedAt;

  // ===========================================================================
  // Remote Synchronization Methods
  // ===========================================================================

  /// Initialize and load cached config immediately, then fetch live from Admin / Supabase
  static Future<void> syncFromBackend() async {
    // 1. Immediately apply cached config from SharedPreferences if present
    await _loadCachedConfig();

    bool synced = false;

    // 2. Primary: Fetch directly from Supabase Cloud REST API for ultra-low latency
    try {
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/auth_settings?id=eq.global&select=*',
      );

      final response = await http.get(
        supabaseUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          _applySupabaseRow(row);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedAuthConfig, jsonEncode(row));
          synced = true;
        }
      }
    } catch (_) {}

    // 3. Fallback: Admin backend API
    if (!synced) {
      try {
        final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/config');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _applyRemoteConfig(data);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedAuthConfig, response.body);
          synced = true;
        }
      } catch (_) {}
    }
  }

  static Future<void> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_prefKeyCachedAuthConfig);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final data = jsonDecode(cachedJson);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('forceUserAuth')) {
            _applyRemoteConfig(data);
          } else if (data.containsKey('force_user_auth')) {
            _applySupabaseRow(data);
          }
        }
      }
    } catch (_) {}
  }

  static void _applyRemoteConfig(Map<String, dynamic> data) {
    if (data['forceUserAuth'] != null) {
      _forceUserAuth = data['forceUserAuth'] == true;
    } else if (data['force_user_auth'] != null) {
      _forceUserAuth = data['force_user_auth'] == true;
    }

    if (data['allowGuestScan'] != null) {
      _allowGuestScan = data['allowGuestScan'] == true;
    } else if (data['allow_guest_scan'] != null) {
      _allowGuestScan = data['allow_guest_scan'] == true;
    }

    if (data['enableContributions'] != null) {
      _enableContributions = data['enableContributions'] == true;
    } else if (data['enable_contributions'] != null) {
      _enableContributions = data['enable_contributions'] == true;
    }

    if (data['requireEmailVerification'] != null) {
      _requireEmailVerification = data['requireEmailVerification'] == true;
    } else if (data['require_email_verification'] != null) {
      _requireEmailVerification = data['require_email_verification'] == true;
    }

    _parseContributionSettings(data);

    _lastSyncedAt = DateTime.now();
  }

  static void _applySupabaseRow(Map<String, dynamic> row) {
    _forceUserAuth = row['force_user_auth'] == true;
    _allowGuestScan = row['allow_guest_scan'] != false;
    
    final contrib = row['enable_contributions'];
    if (contrib is bool) {
      _enableContributions = contrib;
    } else if (contrib is String) {
      _enableContributions = contrib.toLowerCase() == 'true';
    } else if (contrib is num) {
      _enableContributions = contrib != 0;
    } else {
      _enableContributions = contrib != false;
    }

    _requireEmailVerification = row['require_email_verification'] == true;

    _parseContributionSettings(row);

    _lastSyncedAt = DateTime.now();
  }

  static void _parseContributionSettings(Map<String, dynamic> data) {
    // 1. Presets List
    final presetsRaw = data['contributionPresets'] ?? data['contribution_presets'];
    if (presetsRaw != null) {
      if (presetsRaw is List) {
        final list = presetsRaw
            .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()))
            .whereType<double>()
            .toList();
        if (list.isNotEmpty) {
          list.sort();
          _contributionPresets = list;
        }
      } else if (presetsRaw is String) {
        try {
          final decoded = jsonDecode(presetsRaw);
          if (decoded is List) {
            final list = decoded
                .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()))
                .whereType<double>()
                .toList();
            if (list.isNotEmpty) {
              list.sort();
              _contributionPresets = list;
            }
          }
        } catch (_) {}
      }
    }

    // 2. Default & Limits
    final defaultAmt = data['defaultContributionAmount'] ?? data['default_contribution_amount'];
    if (defaultAmt != null) {
      final v = (defaultAmt is num) ? defaultAmt.toDouble() : double.tryParse(defaultAmt.toString());
      if (v != null && v > 0) _defaultContributionAmount = v;
    }

    final minAmt = data['minContributionAmount'] ?? data['min_contribution_amount'];
    if (minAmt != null) {
      final v = (minAmt is num) ? minAmt.toDouble() : double.tryParse(minAmt.toString());
      if (v != null && v > 0) _minContributionAmount = v;
    }

    final maxAmt = data['maxContributionAmount'] ?? data['max_contribution_amount'];
    if (maxAmt != null) {
      final v = (maxAmt is num) ? maxAmt.toDouble() : double.tryParse(maxAmt.toString());
      if (v != null && v > 0) _maxContributionAmount = v;
    }

    final currency = data['contributionCurrency'] ?? data['contribution_currency'];
    if (currency is String && currency.trim().isNotEmpty) {
      _contributionCurrency = currency.trim();
    }

    // 3. Tier Ceilings
    final coffeeCeil = data['coffeeMaxAmount'] ?? data['coffee_max_amount'];
    if (coffeeCeil != null) {
      final v = (coffeeCeil is num) ? coffeeCeil.toDouble() : double.tryParse(coffeeCeil.toString());
      if (v != null) _coffeeMaxAmount = v;
    }

    final serverCeil = data['serverMaxAmount'] ?? data['server_max_amount'];
    if (serverCeil != null) {
      final v = (serverCeil is num) ? serverCeil.toDouble() : double.tryParse(serverCeil.toString());
      if (v != null) _serverMaxAmount = v;
    }

    final growthCeil = data['growthMaxAmount'] ?? data['growth_max_amount'];
    if (growthCeil != null) {
      final v = (growthCeil is num) ? growthCeil.toDouble() : double.tryParse(growthCeil.toString());
      if (v != null) _growthMaxAmount = v;
    }

    // 4. Humanitarian Commitment & Solidarity
    final humEnabled = data['enableHumanitarianCommitment'] ?? data['enable_humanitarian_commitment'];
    if (humEnabled != null) {
      _enableHumanitarianCommitment = humEnabled == true;
    }

    final humTitle = data['humanitarianTitle'] ?? data['humanitarian_title'];
    if (humTitle is String && humTitle.trim().isNotEmpty) {
      _humanitarianTitle = humTitle.trim();
    }

    final humBadge = data['humanitarianBadge'] ?? data['humanitarian_badge'];
    if (humBadge is String && humBadge.trim().isNotEmpty) {
      _humanitarianBadge = humBadge.trim();
    }

    final humShare = data['humanitarianCharityShare'] ?? data['humanitarian_charity_share'];
    if (humShare is String && humShare.trim().isNotEmpty) {
      _humanitarianCharityShare = humShare.trim();
    }

    final humText = data['humanitarianText'] ?? data['humanitarian_text'];
    if (humText is String && humText.trim().isNotEmpty) {
      _humanitarianText = humText.trim();
    }

    final humOrg = data['humanitarianOrganizationName'] ?? data['humanitarian_organization_name'];
    if (humOrg is String && humOrg.trim().isNotEmpty) {
      _humanitarianOrganizationName = humOrg.trim();
    }

    final humUrl = data['humanitarianLearnMoreUrl'] ?? data['humanitarian_learn_more_url'];
    if (humUrl is String && humUrl.trim().isNotEmpty) {
      _humanitarianLearnMoreUrl = humUrl.trim();
    }

    // 5. Stripe Payment Gateway Configuration
    final stripeEnabled = data['enableStripe'] ?? data['enable_stripe'];
    if (stripeEnabled != null) {
      _enableStripe = stripeEnabled == true;
    }

    final mode = data['stripeMode'] ?? data['stripe_mode'];
    if (mode is String && mode.trim().isNotEmpty) {
      _stripeMode = mode.trim().toLowerCase();
    }

    final pubKey = data['stripePublishableKey'] ?? data['stripe_publishable_key'];
    if (pubKey is String) {
      _stripePublishableKey = pubKey.trim();
    }

    final secKey = data['stripeSecretKey'] ?? data['stripe_secret_key'];
    if (secKey is String && secKey.trim().isNotEmpty) {
      _stripeSecretKey = secKey.trim();
    }

    final curr = data['stripeCurrency'] ?? data['stripe_currency'];
    if (curr is String && curr.trim().isNotEmpty) {
      _stripeCurrency = curr.trim().toUpperCase();
    }
  }
}
