class AppConfig {
  AppConfig._();

  /// CRITICAL SECURITY WARNING:
  /// Do NOT hardcode your production Groq API key here for release builds.
  /// Hardcoded keys can be easily extracted from the compiled APK/IPA.
  ///
  /// RECOMMENDED APPROACH:
  /// Pass the key at build time using the --dart-define flag:
  /// flutter build apk --release --dart-define=GROQ_API_KEY=your_key_here
  ///
  /// Then access it using: String.fromEnvironment('GROQ_API_KEY')
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue:
        'YOUR_GROQ_API_KEY_HERE',
  );

  static bool get isAiEnabled => groqApiKey.isNotEmpty;
}
