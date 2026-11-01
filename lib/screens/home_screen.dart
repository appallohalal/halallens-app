import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scanner_provider.dart';
import '../utils/language_helper.dart';
import 'package:iconly/iconly.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import 'scan_screen.dart';
import 'result_screen.dart';
import 'text_scan_screen.dart';
import 'settings_screen.dart';
import 'auth_screen.dart';
import 'banned_screen.dart';
import '../config/auth_config.dart';
import '../services/auth_service.dart';
import '../services/geo_ad_service.dart';
import '../widgets/geo_ad_banner_widget.dart';
import 'support_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScannerProvider>().initialize();
      AdService.instance.preloadInterstitial();
      AuthService.instance.checkBanStatus();
      GeoAdService.instance.refreshNearbyAds();
      AuthConfig.syncFromBackend().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    if (auth.isBanned) {
      return BannedScreen(reason: auth.banReason);
    }

    return Scaffold(
      body: Container(
        color: AppTheme.getBackgroundColor(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Consumer<AuthService>(
                              builder: (context, auth, _) {
                                if (auth.isLoggedIn) {
                                  final user = auth.currentUser!;
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppTheme.primaryBlue
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            IconlyLight.profile,
                                            size: 16,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            user.name.isNotEmpty
                                                ? user.name
                                                : user.username,
                                            style: AppFonts.primary(
                                              context,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.getTextPrimary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AuthScreen(
                                                isMandatory: false,
                                              ),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.getCardColor(context),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppTheme.getBorderColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            IconlyLight.login,
                                            size: 15,
                                            color: AppTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'auth.sign_in'.tr(),
                                            style: AppFonts.primary(
                                              context,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.getTextPrimary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                );
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.getCardColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.getBorderColor(context),
                                  ),
                                ),
                                child: Icon(
                                  IconlyLight.setting,
                                  size: 22,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
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
                                color: AppTheme.getTextPrimary(context),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'home.hero_subtitle'.tr(),
                                textAlign: TextAlign.center,
                                style: AppFonts.primary(
                                  context,
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Column(
                          children: [
                            _buildFeatureRow(
                              IconlyLight.scan,
                              'home.feature_1_title'.tr(),
                              'home.feature_1_desc'.tr(),
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureRow(
                              IconlyLight.image,
                              'home.feature_2_title'.tr(),
                              'home.feature_2_desc'.tr(),
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureRow(
                              IconlyLight.tick_square,
                              'home.feature_3_title'.tr(),
                              'home.feature_3_desc'.tr(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const GeoAdBannerWidget(
                          margin: EdgeInsets.only(bottom: 20),
                        ),
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: () => _navigateToScan(context),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 58),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(IconlyLight.scan, size: 24),
                                    const SizedBox(width: 12),
                                    Text(
                                      'home.scan_barcode'.tr().toUpperCase(),
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: OutlinedButton(
                                onPressed: () => _navigateToTextScan(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.getTextPrimary(
                                    context,
                                  ),
                                  side: BorderSide(
                                    color: AppTheme.getBorderColor(context),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      IconlyLight.image,
                                      size: 24,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'home.analyze_text'.tr().toUpperCase(),
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                        color: AppTheme.getTextPrimary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => _showManualEntry(context),
                              child: Text(
                                'home.manual_entry'.tr(),
                                style: AppFonts.primary(
                                  context,
                                  color: AppTheme.getTextSecondary(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _buildHomeSupportCard(context),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppFonts.primary(
                    context,
                    color: AppTheme.getTextSecondary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkAuthBeforeAction(BuildContext context) async {
    if (AuthConfig.isForceUserAuth && !AuthService.instance.isLoggedIn) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthScreen(isMandatory: true),
        ),
      );
      return success == true || AuthService.instance.isLoggedIn;
    }
    return true;
  }

  Future<void> _navigateToScan(BuildContext context) async {
    final allowed = await _checkAuthBeforeAction(context);
    if (!allowed || !context.mounted) return;
    context.read<ScannerProvider>().reset();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
  }

  Future<void> _navigateToTextScan(BuildContext context) async {
    final allowed = await _checkAuthBeforeAction(context);
    if (!allowed || !context.mounted) return;
    context.read<ScannerProvider>().reset();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TextScanScreen()),
    );
  }

  Future<void> _showManualEntry(BuildContext context) async {
    final allowed = await _checkAuthBeforeAction(context);
    if (!allowed || !context.mounted) return;
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.getBorderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'home.manual_entry_title'.tr(),
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'home.manual_entry_desc'.tr(),
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: AppFonts.primary(
                  context,
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 18,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'home.manual_entry_hint'.tr(),
                  prefixIcon: const Icon(
                    IconlyLight.document,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final barcode = controller.text.trim();
                    if (barcode.isNotEmpty) {
                      Navigator.pop(ctx);
                      context.read<ScannerProvider>().processBarcode(
                        barcode,
                        language: LanguageHelper.getLanguageName(context),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ResultScreen()),
                      );
                    }
                  },
                  child: Text('home.search_product'.tr().toUpperCase()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeSupportCard(BuildContext context) {
    if (!AuthConfig.isContributionsEnabled) return const SizedBox.shrink();
    final isDark = AppTheme.isDark(context);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.12),
            blurRadius: 16,
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
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.3),
            width: 1.3,
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
              SupportScreen.push(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      IconlyBold.heart,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soutenir Allo Halal',
                          style: AppFonts.primary(
                            context,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AuthConfig.humanitarianCharityShare.isNotEmpty
                              ? AuthConfig.humanitarianCharityShare
                              : '20% Redistribué à des œuvres caritatives',
                          style: AppFonts.secondary(
                            context,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Contribuer',
                      style: AppFonts.primary(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
