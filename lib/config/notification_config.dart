import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Server-driven Push Notification Configuration (Firebase Cloud Messaging).
/// Manages FCM credentials and push settings dynamically from the remote Server/Supabase.
class NotificationConfig {
  NotificationConfig._();

  static const String _prefKeyCachedProjectId = 'cached_fcm_project_id';
  static const String _prefKeyCachedApiKey = 'cached_fcm_api_key';
  static const String _prefKeyCachedAppId = 'cached_fcm_app_id';
  static const String _prefKeyCachedMessagingSenderId = 'cached_fcm_messaging_sender_id';
  static const String _prefKeyPushEnabled = 'cached_fcm_push_enabled';

  // Default fallback if not yet set in Admin panel
  static String _firebaseProjectId = 'allo-halal';
  static String _firebaseApiKey = 'AIzaSyCPqOU5ymDEziX2CgcKUCU_p4cUyGQtKYw';
  static String _firebaseAppId = '1:142036889274:android:e5b3b41e042d7d99c9dc83';
  static String _firebaseMessagingSenderId = '142036889274';
  static bool _isEnabled = true;
  static DateTime? _lastSyncedAt;

  static String get firebaseProjectId => _firebaseProjectId;
  static String get firebaseApiKey => _firebaseApiKey;
  static String get firebaseAppId => _firebaseAppId;
  static String get firebaseMessagingSenderId => _firebaseMessagingSenderId;
  static bool get isEnabled => _isEnabled;
  static DateTime? get lastSyncedAt => _lastSyncedAt;
  static bool get isConfigured =>
      _firebaseProjectId.trim().isNotEmpty &&
      _firebaseApiKey.trim().isNotEmpty &&
      _firebaseAppId.trim().isNotEmpty &&
      _firebaseMessagingSenderId.trim().isNotEmpty;

  /// Load cached config immediately, then attempt remote sync
  static Future<void> syncFromBackend() async {
    await _loadCachedConfig();

    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/notifications');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['settings'] != null) {
          final settings = data['settings'] as Map<String, dynamic>;
          final projectId = (settings['firebaseProjectId'] as String? ?? '').trim();
          final apiKey = (settings['firebaseApiKey'] as String? ?? '').trim();
          final appId = (settings['firebaseAppId'] as String? ?? '').trim();
          final senderId = (settings['firebaseMessagingSenderId'] as String? ?? '').trim();
          final enabled = settings['isEnabled'] as bool? ?? true;

          _isEnabled = enabled;
          if (projectId.isNotEmpty) _firebaseProjectId = projectId;
          if (apiKey.isNotEmpty) _firebaseApiKey = apiKey;
          if (appId.isNotEmpty) _firebaseAppId = appId;
          if (senderId.isNotEmpty) _firebaseMessagingSenderId = senderId;
          _lastSyncedAt = DateTime.now();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedProjectId, _firebaseProjectId);
          await prefs.setString(_prefKeyCachedApiKey, _firebaseApiKey);
          await prefs.setString(_prefKeyCachedAppId, _firebaseAppId);
          await prefs.setString(_prefKeyCachedMessagingSenderId, _firebaseMessagingSenderId);
          await prefs.setBool(_prefKeyPushEnabled, _isEnabled);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ NotificationConfig sync info: $e');
      }
    }
  }

  static Future<void> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _firebaseProjectId = prefs.getString(_prefKeyCachedProjectId) ?? '';
      _firebaseApiKey = prefs.getString(_prefKeyCachedApiKey) ?? '';
      _firebaseAppId = prefs.getString(_prefKeyCachedAppId) ?? '';
      _firebaseMessagingSenderId = prefs.getString(_prefKeyCachedMessagingSenderId) ?? '';
      _isEnabled = prefs.getBool(_prefKeyPushEnabled) ?? true;
    } catch (_) {}
  }
}
