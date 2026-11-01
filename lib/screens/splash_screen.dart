import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'no_connection_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'auth_screen.dart';
import 'banned_screen.dart';
import '../config/auth_config.dart';
import '../config/cms_config.dart';
import '../services/auth_service.dart';
import '../theme/app_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/app_logo.png'), context);
  }

  Future<void> _navigateToNextScreen() async {
    final connectivityResults = await Connectivity().checkConnectivity();

    if (connectivityResults.contains(ConnectivityResult.none) ||
        connectivityResults.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const NoConnectionScreen()),
      );
      return;
    }

    // Run remote config syncs & ban check in parallel with a snappy 1.2s splash display.
    // Capped at 2.2s max so slow networks never delay app launch.
    final prefsFuture = SharedPreferences.getInstance();
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1200)),
      Future.wait([
        AuthConfig.syncFromBackend(),
        CmsConfig.syncFromBackend(),
        AuthService.instance.checkBanStatus(),
      ]).timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => [],
      ),
    ]);

    if (!mounted) return;

    if (AuthService.instance.isBanned) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const BannedScreen()),
      );
      return;
    }

    final prefs = await prefsFuture;
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (hasSeenOnboarding) {
      if (AuthConfig.isForceUserAuth && !AuthService.instance.isLoggedIn) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AuthScreen(
              isMandatory: true,
              onSuccess: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/app_logo.png',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'general.app_name'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.getTextPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'general.splash_subtitle'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 16,
                color: AppTheme.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
