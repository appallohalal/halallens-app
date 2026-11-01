import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Purely server-driven Groq AI configuration.
/// No hardcoded API keys or AI models in the mobile app.
/// Follows the identical architectural pattern as AdConfig.
class GroqConfig {
  GroqConfig._();

  static const String _prefKeyCachedGroq = 'cached_groq_remote_config';

  static bool _isEnabled = true;
  static String _apiKey = '';
  static String _model = 'llama-3.3-70b-versatile';
  static String _visionModel = 'llama-3.2-11b-vision-preview';
  static double _temperature = 0.1;
  static int _maxTokens = 2048;

  // ===========================================================================
  // Public Dynamic Getters (Used throughout the App & Services)
  // ===========================================================================

  /// True if AI analysis is enabled by server administrator and API key is present
  static bool get isEnabled => _isEnabled && _apiKey.isNotEmpty;

  /// Groq API key set from Admin
  static String get apiKey => _apiKey;

  /// Active text analysis model (e.g. llama-3.3-70b-versatile)
  static String get model => _model;

  /// Active vision analysis model (e.g. llama-3.2-11b-vision-preview)
  static String get visionModel => _visionModel;

  /// Sampling temperature
  static double get temperature => _temperature;

  /// Maximum tokens per completion
  static int get maxTokens => _maxTokens;

  // ===========================================================================
  // Remote Synchronization Methods
  // ===========================================================================

  /// Initialize and load cached config immediately, then fetch live from Admin
  static Future<void> syncFromBackend() async {
    // 1. Immediately apply cached config from SharedPreferences if present
    await _loadCachedConfig();

    bool synced = false;

    // 2. Primary: Fetch directly from Supabase Cloud REST API for ultra-low latency
    try {
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/groq_settings?id=eq.global&select=*',
      );

      final response = await http.get(
        supabaseUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          _applySupabaseRow(row);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedGroq, jsonEncode(row));
          synced = true;
        }
      }
    } catch (_) {}

    // 3. Fallback: Admin backend API
    if (!synced) {
      try {
        final uri = Uri.parse('${AppConfig.backendBaseUrl}/groq');
        final response =
            await http.get(uri).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _applyRemoteConfig(data);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefKeyCachedGroq, response.body);
          synced = true;
        }
      } catch (_) {}
    }
  }

  static Future<void> _loadCachedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_prefKeyCachedGroq);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final data = jsonDecode(cachedJson);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('apiKey') || data.containsKey('model')) {
            _applyRemoteConfig(data);
          } else if (data.containsKey('api_key')) {
            _applySupabaseRow(data);
          }
        }
      }
    } catch (_) {}
  }

  static void _applyRemoteConfig(Map<String, dynamic> data) {
    if (data['isEnabled'] != null) {
      _isEnabled = data['isEnabled'] == true;
    } else if (data['is_enabled'] != null) {
      _isEnabled = data['is_enabled'] == true;
    }

    if (data['apiKey'] != null) {
      _apiKey = (data['apiKey'] as String).trim();
    } else if (data['api_key'] != null) {
      _apiKey = (data['api_key'] as String).trim();
    }

    if (data['model'] != null && (data['model'] as String).isNotEmpty) {
      _model = data['model'] as String;
    }

    if (data['visionModel'] != null && (data['visionModel'] as String).isNotEmpty) {
      _visionModel = data['visionModel'] as String;
    } else if (data['vision_model'] != null && (data['vision_model'] as String).isNotEmpty) {
      _visionModel = data['vision_model'] as String;
    }

    if (data['temperature'] != null) {
      _temperature = (data['temperature'] as num).toDouble();
    }

    if (data['maxTokens'] != null) {
      _maxTokens = (data['maxTokens'] as num).toInt();
    } else if (data['max_tokens'] != null) {
      _maxTokens = (data['max_tokens'] as num).toInt();
    }
  }

  static void _applySupabaseRow(Map<String, dynamic> row) {
    _isEnabled = row['is_enabled'] == true;
    _apiKey = (row['api_key'] as String?)?.trim() ?? '';
    if (row['model'] != null && (row['model'] as String).isNotEmpty) {
      _model = row['model'] as String;
    }
    if (row['vision_model'] != null && (row['vision_model'] as String).isNotEmpty) {
      _visionModel = row['vision_model'] as String;
    }
    if (row['temperature'] != null) {
      _temperature = (row['temperature'] as num).toDouble();
    }
    if (row['max_tokens'] != null) {
      _maxTokens = (row['max_tokens'] as num).toInt();
    }
  }
}
