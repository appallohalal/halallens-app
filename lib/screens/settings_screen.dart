import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';
import 'saved_products_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';
import 'static_page_screen.dart';
import 'language_screen.dart';
import '../utils/language_helper.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            IconlyLight.arrow_left,
            color: AppTheme.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'settings.title'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('settings.sections.features'.tr()),
              _buildSettingsTile(
                icon: IconlyLight.time_circle,
                title: 'settings.history_title'.tr(),
                subtitle: 'settings.history_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.bookmark,
                title: 'settings.saved_title'.tr(),
                subtitle: 'settings.saved_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SavedProductsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('settings.sections.preferences'.tr()),
              _buildSettingsTile(
                icon: IconlyLight.discovery,
                title: 'settings.language_title'.tr(),
                subtitle: LanguageHelper.getNativeLanguageName(context),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.image,
                title: 'settings.theme_title'.tr(),
                subtitle: _getThemeName(context),
                onTap: () => _showThemePicker(context),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('settings.sections.about'.tr()),
              _buildSettingsTile(
                icon: IconlyLight.message,
                title: 'settings.help_title'.tr(),
                subtitle: 'settings.help_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        title: 'settings.help_title'.tr(),
                        content: 'settings.help_content'.tr(),
                        icon: IconlyLight.message,
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.shield_done,
                title: 'settings.privacy_title'.tr(),
                subtitle: 'settings.privacy_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        title: 'settings.privacy_title'.tr(),
                        content: 'settings.privacy_content'.tr(),
                        icon: IconlyLight.shield_done,
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.info_square,
                title: 'settings.about_title'.tr(),
                subtitle: 'settings.about_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        title: 'settings.about_title'.tr(),
                        content: 'settings.about_content'.tr(),
                        icon: IconlyLight.info_square,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeName(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    switch (themeService.themeMode) {
      case ThemeMode.system:
        return 'general.system_default'.tr();
      case ThemeMode.light:
        return 'general.light'.tr();
      case ThemeMode.dark:
        return 'general.dark'.tr();
    }
  }

  void _showThemePicker(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.getBackgroundColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.getTextSecondary(
                          context,
                        ).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'settings.theme_title'.tr(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getTextPrimary(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'settings.theme_desc'.tr(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 14,
                      color: AppTheme.getTextSecondary(context),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _themeOption(
                    context,
                    themeService,
                    ThemeMode.system,
                    'general.system_default'.tr(),
                    IconlyLight.setting,
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    context,
                    themeService,
                    ThemeMode.light,
                    'general.light'.tr(),
                    IconlyLight.show,
                  ),
                  const SizedBox(height: 10),
                  _themeOption(
                    context,
                    themeService,
                    ThemeMode.dark,
                    'general.dark'.tr(),
                    IconlyLight.hide,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeService themeService,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final bool isSelected = themeService.themeMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          themeService.setThemeMode(mode);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                : AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryBlue
                  : AppTheme.getBorderColor(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                      : AppTheme.getTextSecondary(
                          context,
                        ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : AppTheme.getTextSecondary(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.primary(
                    context,
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : AppTheme.getTextPrimary(context),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  IconlyBold.tick_square,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.primary(
          context,
          color: AppTheme.getTextSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
        ),
        title: Text(
          title,
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        trailing: Icon(
          IconlyLight.arrow_right_2,
          color: AppTheme.getTextMuted(context),
          size: 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
      ),
    );
  }
}
