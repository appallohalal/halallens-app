import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../services/theme_service.dart';
import 'home_screen.dart';

class ThemeOnboardingScreen extends StatefulWidget {
  const ThemeOnboardingScreen({super.key});

  @override
  State<ThemeOnboardingScreen> createState() => _ThemeOnboardingScreenState();
}

class _ThemeOnboardingScreenState extends State<ThemeOnboardingScreen> {
  late ThemeMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = ThemeMode.system;
  }

  Future<void> _onContinue() async {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    await themeService.setThemeMode(_selectedMode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'settings.theme_title'.tr(),
                style: AppFonts.primary(
                  context,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settings.theme_desc'.tr(),
                style: AppFonts.primary(
                  context,
                  fontSize: 14,
                  color: AppTheme.getTextSecondary(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _themeOption(
                context: context,
                mode: ThemeMode.system,
                label: 'general.system_default'.tr(),
                icon: Icons.brightness_auto,
              ),
              _themeOption(
                context: context,
                mode: ThemeMode.light,
                label: 'general.light'.tr(),
                icon: Icons.light_mode,
              ),
              _themeOption(
                context: context,
                mode: ThemeMode.dark,
                label: 'general.dark'.tr(),
                icon: Icons.dark_mode,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _onContinue,
                  child: Text(
                    'onboarding.get_started'.tr(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption({
    required BuildContext context,
    required ThemeMode mode,
    required String label,
    required IconData icon,
  }) {
    final bool isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryBlue
                : AppTheme.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryBlue
                  : AppTheme.getTextSecondary(context),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppFonts.primary(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextPrimary(context),
                ),
              ),
            ),
            if (isSelected)
              Icon(IconlyBold.tick_square, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }
}
