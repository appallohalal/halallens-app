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
  static bool _requireEmailVerification = false;
  static DateTime? _lastSyncedAt;

  // ===========================================================================
  // Public Dynamic Getters (Used throughout the App & Services)
  // ===========================================================================

  /// When true, user account creation / login is mandatory before scanning.
  /// When false (V1 default), users can freely scan anonymously as guests.
  static bool get isForceUserAuth => _forceUserAuth;

  /// True if guest scanning is allowed without registration.
  static bool get allowGuestScan => _allowGuestScan && !_forceUserAuth;

  /// True if registered users must verify their email address.
  static bool get requireEmailVerification => _requireEmailVerification;

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

    // 2. Try fetching from Local Admin backend
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/config');

      final response =
          await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _applyRemoteConfig(data);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyCachedAuthConfig, response.body);
        synced = true;

        if (kDebugMode) {
          debugPrint(
            '✅ [AuthConfig] Synced from Local Server: '
            'forceUserAuth=$isForceUserAuth, '
            'allowGuestScan=$allowGuestScan',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ [AuthConfig] Local server unreachable ($e), trying Supabase cloud...');
      }
    }

    // 3. Resilient fallback: Try Supabase Cloud directly if local server timed out
    if (!synced) {
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
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final row = list.first as Map<String, dynamic>;
            _applySupabaseRow(row);

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKeyCachedAuthConfig, jsonEncode(row));
            synced = true;

            if (kDebugMode) {
              debugPrint(
                '✅ [AuthConfig] Synced directly from Supabase Cloud: '
                'forceUserAuth=$isForceUserAuth, '
                'allowGuestScan=$allowGuestScan',
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [AuthConfig] Supabase cloud sync note: $e');
        }
      }
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

    if (data['requireEmailVerification'] != null) {
      _requireEmailVerification = data['requireEmailVerification'] == true;
    } else if (data['require_email_verification'] != null) {
      _requireEmailVerification = data['require_email_verification'] == true;
    }

    _lastSyncedAt = DateTime.now();
  }

  static void _applySupabaseRow(Map<String, dynamic> row) {
    _forceUserAuth = row['force_user_auth'] == true;
    _allowGuestScan = row['allow_guest_scan'] != false;
    _requireEmailVerification = row['require_email_verification'] == true;
    _lastSyncedAt = DateTime.now();
  }
}
