import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'groq_config.dart';

class AppConfig {
  AppConfig._();

  /// Remote backend URL (Next.js / Supabase Admin)
  /// Can be overridden at build time via --dart-define=BACKEND_URL=https://admin.yourdomain.com/api/v1
  static const String _envBackendUrl = String.fromEnvironment('BACKEND_URL');

  static const int backendPort = 3000;
  static const String backendHost = '192.168.10.71';

  /// Supabase Cloud configuration for direct resilient access
  static const String supabaseUrl = 'https://nkhlqwotyadtzdtmkatj.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_a0ryV5Kjh5lbsnsK1V5Q0g_-r1tsj1c';

  static String get backendBaseUrl {
    if (_envBackendUrl.isNotEmpty) return _envBackendUrl;
    if (kIsWeb) return 'http://localhost:$backendPort/api/v1';
    try {
      if (Platform.isAndroid) {
        // Works on real Android device on local Wi-Fi and emulator
        return 'http://$backendHost:$backendPort/api/v1';
      } else if (Platform.isIOS || Platform.isMacOS) {
        return 'http://localhost:$backendPort/api/v1';
      }
    } catch (_) {}
    return 'http://$backendHost:$backendPort/api/v1';
  }

  /// AI Analysis is managed dynamically from the remote Server/Supabase via GroqConfig.
  /// No API keys or AI models are hardcoded in the mobile application.
  static bool get isAiEnabled => GroqConfig.isEnabled;
}

