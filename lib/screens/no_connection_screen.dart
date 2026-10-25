import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:iconly/iconly.dart';
import '../theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';

class NoConnectionScreen extends StatefulWidget {
  const NoConnectionScreen({super.key});

  @override
  State<NoConnectionScreen> createState() => _NoConnectionScreenState();
}

class _NoConnectionScreenState extends State<NoConnectionScreen> {
  bool _isChecking = false;

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);

    // Minimal delay for visual feedback
    await Future.delayed(const Duration(seconds: 1));

    final results = await Connectivity().checkConnectivity();

    // Check if we have any active connection that is NOT ConnectivityResult.none
    final hasInternet = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (hasInternet) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'connection.no_internet_msg'.tr(),
              style: AppFonts.primary(context),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                IconlyBold.shield_fail,
                size: 80,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'connection.no_internet_title'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'connection.no_internet_desc'.tr(),
              style: AppFonts.primary(
                context,
                fontSize: 16,
                color: AppTheme.getTextSecondary(context),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _checkConnection,
                child: _isChecking
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('connection.try_again'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
