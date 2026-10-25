# HalalLens — AI Food Scanner & Ingredient Analyzer Flutter Mobile App

HalalLens is a commercial-grade Flutter application powered by Groq AI's ultra-fast LPU inference engine for instant Halal, Haram, and Doubtful ingredient identification and barcode scanning.

## Tech Stack
- **Framework:** Flutter 3.44+
- **Language:** Dart 3.11+
- **AI Inference Engine:** Groq API (`openai/gpt-oss-120b` & `qwen/qwen3.8-27b`)
- **State Management:** Provider Pattern
- **Local Storage:** Hive Database
- **Monetization:** Google AdMob (Banner, Interstitial, App Open, Native)
- **UI:** Material Design 3 (Light & Dark Mode)

## Setup & Configuration
1. Run `flutter pub get` to install all dependencies.
2. Configure your Groq API key in `lib/config/app_config.dart` or via `--dart-define=GROQ_API_KEY=your_key_here`.
3. Configure your production AdMob IDs in `lib/config/ad_config.dart` and set `productionAdsEnabled = true`.
4. Run `flutter run` or build release binaries via `flutter build apk` / `flutter build ipa`.

## Support & Documentation
For setup assistance or queries, contact hello@softsync.agency.
