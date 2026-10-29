import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';

import '../config/auth_config.dart';
import '../services/stripe_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/stripe_payment_sheet.dart';

/// Full Dedicated Screen for Community Contributions ("Support the Project - Prix libre").
/// Strictly adheres to the Allo Halal design language and app pattern.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late double _contributionAmount;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _contributionAmount = AuthConfig.defaultContributionAmount;
  }

  String _getTierDescription(double amount) {
    if (amount <= AuthConfig.coffeeMaxAmount) {
      return 'support.tier_coffee'.tr();
    } else if (amount <= AuthConfig.serverMaxAmount) {
      return 'support.tier_server'.tr();
    } else if (amount <= AuthConfig.growthMaxAmount) {
      return 'support.tier_growth'.tr();
    } else {
      return 'support.tier_patron'.tr();
    }
  }

  Future<void> _handleContribution() async {
    if (_isProcessing) return;

    if (!AuthConfig.isStripeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(IconlyBold.heart, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'support.thank_you'.tr(),
                  style: AppFonts.primary(
                    context,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final tierName = _contributionAmount <= AuthConfig.coffeeMaxAmount
          ? 'COFFEE'
          : _contributionAmount <= AuthConfig.serverMaxAmount
              ? 'SERVER'
              : _contributionAmount <= AuthConfig.growthMaxAmount
                  ? 'GROWTH'
                  : 'PATRON';

      final sessionResult = await StripeService.instance.createStripeSession(
        amount: _contributionAmount,
        tier: tierName,
        message: 'Community Contribution via Allo Halal App',
      );

      if (!mounted) return;

      if (!sessionResult.success || sessionResult.url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sessionResult.message,
              style: AppFonts.primary(context, color: Colors.white),
            ),
            backgroundColor: AppTheme.haramRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      // Open the Stripe payment gateway directly inside an in-app Bottom Sheet
      final paid = await StripePaymentSheet.show(
        context,
        checkoutUrl: sessionResult.url!,
        sessionId: sessionResult.sessionId,
        amount: _contributionAmount,
      );

      if (!mounted) return;

      if (paid == true) {
        if (sessionResult.sessionId != null) {
          StripeService.instance.syncCompletedSession(sessionResult.sessionId!);
        }
        Navigator.pop(context); // Return to previous screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(IconlyBold.shield_done, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'support.thank_you'.tr(),
                    style: AppFonts.primary(
                      context,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF088839),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.primary(
          context,
          color: AppTheme.getTextSecondary(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
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
          'settings.support_project_title'.tr(),
          style: AppFonts.primary(
            context,
            color: AppTheme.getTextPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Overview Card (Amber, Gold & Warm Green Accent)
                    _buildSectionTitle('settings.sections.about'.tr()),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                              : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.35,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    IconlyBold.heart,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'support.title'.tr(),
                                      style: AppFonts.primary(
                                        context,
                                        color: AppTheme.getTextPrimary(context),
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF088839).withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF088839).withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'support.no_commitment'.tr(),
                                        style: AppFonts.primary(
                                          context,
                                          color: const Color(0xFF088839),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'support.desc'.tr(),
                            style: AppFonts.primary(
                              context,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFD1D5DB)
                                  : const Color(0xFF4B5563),
                              fontSize: 13,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Choose Amount (Vibrant & Warm Styled Card)
                    _buildSectionTitle('support.slider_label'.tr()),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: Theme.of(context).brightness == Brightness.dark
                              ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                              : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.35,
                          ),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_contributionAmount.toInt()} €',
                            style: AppFonts.primary(
                              context,
                              color: const Color(0xFF088839),
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getTierDescription(_contributionAmount),
                              textAlign: TextAlign.center,
                              style: AppFonts.primary(
                                context,
                                color: const Color(0xFFD97706),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Slider
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppTheme.primaryBlue,
                              inactiveTrackColor: AppTheme.getBorderColor(context),
                              thumbColor: AppTheme.primaryBlue,
                              overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              trackHeight: 5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value: _contributionAmount.clamp(
                                AuthConfig.minContributionAmount,
                                AuthConfig.maxContributionAmount,
                              ),
                              min: AuthConfig.minContributionAmount,
                              max: AuthConfig.maxContributionAmount,
                              divisions: (AuthConfig.maxContributionAmount - AuthConfig.minContributionAmount)
                                  .toInt()
                                  .clamp(1, 100),
                              onChanged: (val) {
                                setState(() => _contributionAmount = val);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Preset Chips
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: AuthConfig.contributionPresets.map((p) {
                              final isSelected = (_contributionAmount.toInt() == p.toInt());
                              final currencySymbol = AuthConfig.contributionCurrency == 'EUR'
                                  ? '€'
                                  : AuthConfig.contributionCurrency;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: InkWell(
                                    onTap: () => setState(() => _contributionAmount = p),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryBlue
                                            : AppTheme.getCardColor(context),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryBlue
                                              : AppTheme.getBorderColor(context),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${p.toInt()} $currencySymbol',
                                          style: AppFonts.primary(
                                            context,
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : AppTheme.getTextPrimary(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    // Section 3: Humanitarian Commitment (if enabled)
                    if (AuthConfig.isHumanitarianCommitmentEnabled) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(AuthConfig.humanitarianTitle),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.halalGreen.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.halalGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    IconlyBold.shield_done,
                                    color: AppTheme.halalGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AuthConfig.humanitarianTitle,
                                    style: AppFonts.primary(
                                      context,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.halalGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    AuthConfig.humanitarianCharityShare,
                                    style: AppFonts.primary(
                                      context,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.halalGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AuthConfig.humanitarianText,
                              style: AppFonts.primary(
                                context,
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                            if (AuthConfig.humanitarianOrganizationName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    IconlyLight.heart,
                                    size: 14,
                                    color: AppTheme.halalGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      AuthConfig.humanitarianOrganizationName,
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.halalGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Pinned Bottom Action Container (App Pattern)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleContribution,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  IconlyBold.heart,
                                  color: Color(0xFFFBBF24),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'support.btn_contribute'.tr(
                                    args: ['${_contributionAmount.toInt()}'],
                                  ),
                                  style: AppFonts.primary(
                                    context,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        IconlyLight.shield_done,
                        size: 13,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Powered by Stripe • 256-Bit SSL Encrypted',
                        style: AppFonts.primary(
                          context,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
