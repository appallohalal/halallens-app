import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'providers/scanner_provider.dart';
import 'services/theme_service.dart';
import 'services/history_service.dart';
import 'services/saved_product_service.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'config/groq_config.dart';
import 'config/auth_config.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  await EasyLocalization.ensureInitialized();
  await HistoryService.init();
  await SavedProductService.init();
  await AuthService.instance.init(); // Initialize user session cache
  await AdService.initialize(); // No-op if ads disabled in AdConfig
  await GroqConfig.syncFromBackend(); // Sync remote Groq AI configuration
  await AuthConfig.syncFromBackend(); // Sync remote Mandatory Registration toggle

  final themeService = ThemeService();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
        Locale('ur'),
        Locale('tr'),
        Locale('id'),
        Locale('bn'),
        Locale('es'),
        Locale('hi'),
        Locale('de'),
        Locale('zh'),
        Locale('ru'),
        Locale('pt'),
        Locale('it'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScannerProvider()),
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider.value(value: AuthService.instance),
        ],
        child: const HalalLensApp(),
      ),
    ),
  );
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
