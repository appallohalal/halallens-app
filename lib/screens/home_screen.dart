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
    });
  }

  @override
  Widget build(BuildContext context) {
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
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
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
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                IconlyBold.shield_done,
                                size: 48,
                                color: Colors.white,
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'home.powered_by'.tr(),
                              style: AppFonts.primary(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.getTextSecondary(
                                  context,
                                ).withValues(alpha: 0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'general.groq_ai'.tr(),
                              style: AppFonts.primary(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.getTextPrimary(context),
                                letterSpacing: 1.0,
                              ),
                            ),
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
          Icon(
            IconlyLight.arrow_right_2,
            color: AppTheme.getTextMuted(context),
          ),
        ],
      ),
    );
  }

  void _navigateToScan(BuildContext context) {
    context.read<ScannerProvider>().reset();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    );
  }

  void _navigateToTextScan(BuildContext context) {
    context.read<ScannerProvider>().reset();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TextScanScreen()),
    );
  }

  void _showManualEntry(BuildContext context) {
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
}
