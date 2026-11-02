import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter_stripe/flutter_stripe.dart';

import 'providers/scanner_provider.dart';
import 'services/theme_service.dart';
import 'services/history_service.dart';
import 'services/saved_product_service.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'config/auth_config.dart';
import 'config/groq_config.dart';
import 'config/cms_config.dart';
import 'config/notification_config.dart';
import 'services/notification_service.dart';
import 'services/geo_ad_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];

  // Fast local-only initialization (< 30ms) so the first frame renders immediately
  // without any black screen or network delay.
  final themeService = ThemeService();
  await CmsConfig.loadCachedOnly();
  await Hive.initFlutter();

  // Sanitize saved locale in SharedPreferences to prevent loading deleted locale assets
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale');
    const supported = ['fr', 'en', 'ar', 'es', 'it', 'de', 'pt', 'tr', 'ru'];
    if (saved != null && !supported.contains(saved.split('_')[0])) {
      await prefs.setString('locale', 'fr');
    }
  } catch (_) {}

  await Future.wait([
    EasyLocalization.ensureInitialized(),
    HistoryService.init(),
    SavedProductService.init(),
    AuthService.instance.init(),
    themeService.loadTheme(),
  ]);

  // Initialize Stripe SDK safely only if a valid publishable key exists
  if (AuthConfig.hasValidStripePublishableKey) {
    try {
      Stripe.publishableKey = AuthConfig.stripePublishableKey.trim();
      Stripe.merchantIdentifier = 'merchant.com.allohalal';
      await Stripe.instance.applySettings();
    } catch (_) {}
  }

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
        Locale('es'),
        Locale('it'),
        Locale('de'),
        Locale('pt'),
        Locale('tr'),
        Locale('ru'),
      ],
      path: 'assets/translations',
      startLocale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      assetLoader: const CmsAssetLoader(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScannerProvider()),
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: AuthService.instance),
          ChangeNotifierProvider.value(value: GeoAdService.instance),
        ],
        child: const HalalLensApp(),
      ),
    ),
  );

  // Run all remote syncs and SDK initializations asynchronously in the background
  // after the first UI frame is painted.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initBackgroundServices());
  });
}

Future<void> _initBackgroundServices() async {
  try {
    await AuthConfig.syncFromBackend();
    if (AuthConfig.hasValidStripePublishableKey) {
      Stripe.publishableKey = AuthConfig.stripePublishableKey.trim();
      Stripe.merchantIdentifier = 'merchant.com.allohalal';
      await Stripe.instance.applySettings();
    }
  } catch (_) {}

  try {
    await GroqConfig.syncFromBackend();
  } catch (_) {}

  try {
    await AdService.initialize();
  } catch (_) {}

  try {
    await NotificationConfig.syncFromBackend();
    await NotificationService.instance.init();
    await NotificationService.instance
        .syncUserTags(AuthService.instance.currentUser);
  } catch (_) {}
}

class HalalLensApp extends StatefulWidget {
  const HalalLensApp({super.key});

  @override
  State<HalalLensApp> createState() => _HalalLensAppState();
}

class _HalalLensAppState extends State<HalalLensApp>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lastState != null &&
        (_lastState == AppLifecycleState.paused ||
            _lastState == AppLifecycleState.inactive) &&
        state == AppLifecycleState.resumed) {
      AdService.instance.showAppOpenAd();
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      onGenerateTitle: (context) => 'general.app_name'.tr(),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: themeService.themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: brightness == Brightness.dark
                ? AppTheme.backgroundDark
                : AppTheme.backgroundLight,
            systemNavigationBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
