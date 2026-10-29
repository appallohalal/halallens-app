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
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import '../config/cms_config.dart';
import '../config/auth_config.dart';
import '../widgets/support_dialog.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    CmsConfig.syncFromBackend();
    AuthConfig.syncFromBackend().then((_) {
      if (mounted) setState(() {});
    });
  }

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
              _buildSectionTitle('settings.sections.account'.tr()),
              _buildAccountTile(context),
              _buildSupportBanner(context),
              const SizedBox(height: 16),
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
                title: CmsConfig.getText('helpTitle', fallback: 'settings.help_title'.tr()),
                subtitle: 'settings.help_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        pageKey: 'help',
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
                title: CmsConfig.getText('privacyTitle', fallback: 'settings.privacy_title'.tr()),
                subtitle: 'settings.privacy_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        pageKey: 'privacy',
                        title: 'settings.privacy_title'.tr(),
                        content: 'settings.privacy_content'.tr(),
                        icon: IconlyLight.shield_done,
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.document,
                title: CmsConfig.getText('termsTitle', fallback: 'auth.terms_title'.tr()),
                subtitle: 'auth.terms_title'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        pageKey: 'terms',
                        title: 'auth.terms_title'.tr(),
                        content: 'auth.terms_content'.tr(),
                        icon: IconlyLight.document,
                      ),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: IconlyLight.info_square,
                title: CmsConfig.getText('aboutTitle', fallback: 'settings.about_title'.tr()),
                subtitle: 'settings.about_desc'.tr(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaticPageScreen(
                        pageKey: 'about',
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
    return (themeService.themeMode == ThemeMode.dark)
        ? 'general.dark'.tr()
        : 'general.light'.tr();
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
    Color? iconColor,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.getBorderColor(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.getBackgroundColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? AppTheme.primaryBlue, size: 22),
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
        trailing: trailing ??
            Icon(
              IconlyLight.arrow_right_2,
              color: AppTheme.getTextMuted(context),
              size: 20,
            ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final isLoggedIn = auth.isLoggedIn;
        final user = auth.currentUser;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLoggedIn
                  ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                  : AppTheme.getBorderColor(context),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isLoggedIn ? IconlyBold.profile : IconlyLight.user,
                        color: AppTheme.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLoggedIn
                                ? (user?.name.isNotEmpty == true
                                    ? user!.name
                                    : (user?.username ?? 'settings.user_default'.tr()))
                                : 'settings.guest_account'.tr(),
                            style: AppFonts.primary(
                              context,
                              color: AppTheme.getTextPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLoggedIn
                                ? '${user?.email ?? ''}${user?.city.isNotEmpty == true ? ' • ${user!.city}, ${user.country}' : ''}'
                                : 'settings.guest_subtitle'.tr(),
                            style: AppFonts.primary(
                              context,
                              color: AppTheme.getTextSecondary(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLoggedIn)
                      IconButton(
                        tooltip: 'settings.sign_out'.tr(),
                        icon: const Icon(
                          IconlyLight.logout,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        onPressed: () => _confirmSignOut(context),
                      ),
                  ],
                ),
                if (isLoggedIn) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(IconlyLight.edit, size: 15),
                          label: Text(
                            'settings.edit_profile'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryBlue,
                            side: BorderSide(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            IconlyLight.delete,
                            size: 15,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            'settings.delete_account'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _confirmDeleteAccount(context),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isLoggedIn) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(IconlyLight.login, size: 18),
                      label: Text(
                        'settings.sign_in_register'.tr(),
                        style: AppFonts.primary(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AuthScreen(isMandatory: false),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportBanner(BuildContext context) {
    if (!AuthConfig.isContributionsEnabled) {
      return const SizedBox.shrink();
    }
    final isDark = AppTheme.isDark(context);

    // Eye-catching, spacious hero block with Warm Amber, Gold and Warm Green accents
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.5 : 0.35),
            width: 1.4,
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF261D0F), const Color(0xFF13251A)]
                  : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () {
              SupportDialog.show(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Radiant Gold & Amber Gradient Icon Box (Spacious 52x52)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            IconlyBold.heart,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'settings.support_project_title'.tr(),
                                    style: AppFonts.primary(
                                      context,
                                      color: AppTheme.getTextPrimary(context),
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    '★ Prix libre',
                                    style: TextStyle(
                                      color: Color(0xFFD97706),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'settings.support_project_subtitle'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            IconlyLight.arrow_right_2,
                            color: Color(0xFFD97706),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Bottom Highlights Pill Row giving grand height and visual richness
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF088839).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF088839).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(IconlyBold.shield_done, color: Color(0xFF088839), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'support.no_commitment'.tr(),
                              style: AppFonts.primary(
                                context,
                                color: const Color(0xFF088839),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'settings.sign_out'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'settings.sign_out_confirm'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('general.cancel'.tr(), style: AppFonts.primary(context)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.logout();
            },
            child: Text('settings.sign_out'.tr(), style: AppFonts.primary(context)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(IconlyBold.delete, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'settings.delete_account'.tr(),
                  style: AppFonts.primary(
                    context,
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'settings.delete_account_confirm'.tr(),
            style: AppFonts.primary(
              context,
              color: AppTheme.getTextSecondary(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(
                'general.cancel'.tr(),
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        final res = await AuthService.instance.deleteAccount();
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.message ?? 'settings.delete_account_success'.tr(),
                                style: AppFonts.primary(context, color: Colors.white),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isDeleting = false);
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'settings.delete_account_btn'.tr(),
                      style: AppFonts.primary(context, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

