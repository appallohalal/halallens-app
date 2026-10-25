# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-09-22
### Changed
- Text ingredient analysis now uses Groq model `openai/gpt-oss-120b`.
- Ingredient label photos now use Groq model `qwen/qwen3.8-27b`.
- AdMob always uses the production ad unit IDs. Debug builds no longer switch to test ads automatically.
- Failed Groq requests now show the API error instead of failing silently.

### Fixed
- Android debug builds failed because Iconly subclassed `IconData`, which current Flutter marks as final. The app now uses a local patched copy of Iconly.

## [1.0.0] - 2026-03-18
### Added
- Initial release of HalalLens.
- AI-powered Halal product scanner using Groq API.
- Barcode scanning for instant results.
- Support for multiple languages (Easy Localization).
- AdMob integration for monetization.
- Save favorites and scan history.
- Added `hive_generator` and `build_runner` for local database adapters.
- Security enhancement: Groq API key now recommended via `--dart-define`.
- Comprehensive offline documentation.
- Android release signing instructions and configuration.
