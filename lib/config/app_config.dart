import 'groq_config.dart';

class AppConfig {
  AppConfig._();

  /// Live Production Admin Backend URL (Vercel)
  static const String _envBackendUrl = String.fromEnvironment('BACKEND_URL');
  static const String _liveBackendUrl =
      'https://allohalal-admin.vercel.app/api/v1';

  /// Supabase Cloud configuration for direct resilient access
  static const String supabaseUrl = 'https://mkqovvoarufmawtosfbi.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_hUN6voInwirFJLjhmee8fg_t1THznkJ';

  static String get backendBaseUrl {
    if (_envBackendUrl.isNotEmpty) return _envBackendUrl;
    return _liveBackendUrl;
  }

  /// AI Analysis is managed dynamically from the remote Server/Supabase via GroqConfig.
  /// No API keys or AI models are hardcoded in the mobile application.
  static bool get isAiEnabled => GroqConfig.isEnabled;
}

