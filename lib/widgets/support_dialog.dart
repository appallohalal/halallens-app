import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/auth_config.dart';
import '../screens/support_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'contribution_success_dialog.dart';
import 'payment_method_bottom_sheet.dart';

/// Free-will contribution model ("Prix libre") displayed in an elegant Bottom Sheet.
/// Features a draggable handle, smooth scrolling, and in-app Stripe & PayPal payment selection.
class SupportDialog extends StatefulWidget {
  const SupportDialog({super.key});

  /// Forwards directly to the dedicated full SupportScreen.
  static Future<void> show(BuildContext context) {
    return SupportScreen.push(context);
  }

  @override
  State<SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> {
  late double _contributionAmount;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _contributionAmount = AuthConfig.defaultContributionAmount.clamp(
      AuthConfig.minContributionAmount,
      AuthConfig.maxContributionAmount,
    );
    // Refresh live configuration from Supabase immediately on open
    AuthConfig.syncFromBackend().then((_) {
      if (mounted) {
        setState(() {
          _contributionAmount = AuthConfig.defaultContributionAmount.clamp(
            AuthConfig.minContributionAmount,
            AuthConfig.maxContributionAmount,
          );
        });
      }
    });
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

    if (!AuthConfig.isPaymentGatewayEnabled) {
      Navigator.pop(context);
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

      final user = AuthService.instance.currentUser;
      final donorEmail = user?.email.trim() ?? '';
      final donorName = (user?.name.trim().isNotEmpty == true)
          ? user!.name.trim()
          : (user?.username.trim().isNotEmpty == true ? user!.username.trim() : '');

      // Open the modern Payment Method Bottom Sheet (Stripe & PayPal)
      final paid = await PaymentMethodBottomSheet.show(
        context,
        amount: _contributionAmount,
        tier: tierName,
        donorName: donorName.isNotEmpty ? donorName : null,
        donorEmail: donorEmail.isNotEmpty ? donorEmail : null,
        message: 'Community Contribution via Allo Halal App',
      );

      if (!mounted) return;

      if (paid == true) {
        Navigator.pop(context); // Close the support selection bottom sheet
        await ContributionSuccessDialog.show(
          context,
          amount: _contributionAmount,
          tier: tierName,
          donorName: donorName.isNotEmpty ? donorName : null,
          donorEmail: donorEmail.isNotEmpty ? donorEmail : null,
          paymentMethod: 'Stripe / PayPal',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.getTextSecondary(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),

            // Flexible Scrollable Body (Guarantees zero RenderFlex overflow)
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Card (Amber, Gold & Warm Green Accent)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                              : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
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
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            AuthConfig.contributionTitle.isNotEmpty
                                                ? AuthConfig.contributionTitle
                                                : 'support.title'.tr(),
                                            style: AppFonts.primary(
                                              context,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.getTextPrimary(context),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.16),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Text(
                                            '★ Prix libre',
                                            style: TextStyle(
                                              color: Color(0xFFD97706),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      AuthConfig.contributionSubtitle.isNotEmpty
                                          ? AuthConfig.contributionSubtitle
                                          : 'support.no_commitment'.tr(),
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF088839),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AuthConfig.contributionDesc.isNotEmpty
                                ? AuthConfig.contributionDesc
                                : 'support.desc'.tr(),
                            style: AppFonts.primary(
                              context,
                              fontSize: 12.5,
                              height: 1.45,
                              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Big Amount Display Card (Amber & Green Design)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                              : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.45 : 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            (_contributionAmount == _contributionAmount.roundToDouble())
                                ? '${_contributionAmount.toInt()} ${AuthConfig.contributionCurrency == 'EUR' ? '€' : AuthConfig.contributionCurrency}'
                                : '${_contributionAmount.toStringAsFixed(2)} ${AuthConfig.contributionCurrency == 'EUR' ? '€' : AuthConfig.contributionCurrency}',
                            style: AppFonts.primary(
                              context,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF088839),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _getTierDescription(_contributionAmount),
                              textAlign: TextAlign.center,
                              style: AppFonts.primary(
                                context,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF088839),
                        inactiveTrackColor: AppTheme.getBorderColor(context),
                        thumbColor: const Color(0xFF088839),
                        overlayColor: const Color(0xFF088839).withValues(alpha: 0.15),
                        trackHeight: 5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: _contributionAmount.clamp(
                          AuthConfig.minContributionAmount,
                          AuthConfig.maxContributionAmount,
                        ),
                        min: AuthConfig.minContributionAmount,
                        max: AuthConfig.maxContributionAmount > AuthConfig.minContributionAmount
                            ? AuthConfig.maxContributionAmount
                            : AuthConfig.minContributionAmount + 1,
                        divisions: (AuthConfig.maxContributionAmount - AuthConfig.minContributionAmount) > 0
                            ? (AuthConfig.maxContributionAmount - AuthConfig.minContributionAmount)
                                .toInt()
                                .clamp(1, 100)
                            : 1,
                        onChanged: (val) {
                          setState(() => _contributionAmount = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preset Chips (Dynamic Wrap)
                    Center(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: AuthConfig.contributionPresets.map((p) {
                          final isSelected = ((_contributionAmount - p).abs() < 0.01);
                          final currencySymbol = AuthConfig.contributionCurrency == 'EUR'
                              ? '€'
                              : AuthConfig.contributionCurrency;
                          final amountText = (p == p.roundToDouble())
                              ? '${p.toInt()} $currencySymbol'
                              : '${p.toStringAsFixed(2)} $currencySymbol';

                          return InkWell(
                            onTap: () => setState(() => _contributionAmount = p),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF088839)
                                    : AppTheme.getCardColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF088839)
                                      : AppTheme.getBorderColor(context),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                amountText,
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.getTextPrimary(context),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Humanitarian Commitment & Solidarity Card (if enabled)
                    if (AuthConfig.isHumanitarianCommitmentEnabled) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    IconlyBold.shield_done,
                                    color: Color(0xFF088839),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AuthConfig.humanitarianTitle,
                                        style: AppFonts.primary(
                                          context,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.getTextPrimary(context),
                                        ),
                                      ),
                                      if (AuthConfig.humanitarianBadge.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF088839).withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            AuthConfig.humanitarianBadge,
                                            style: const TextStyle(
                                              color: Color(0xFF088839),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (AuthConfig.humanitarianCharityShare.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      AuthConfig.humanitarianCharityShare,
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF088839),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            if (AuthConfig.humanitarianOrganizationName.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(IconlyLight.heart, size: 13, color: Color(0xFF088839)),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      AuthConfig.humanitarianOrganizationName,
                                      style: AppFonts.primary(
                                        context,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF088839),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (AuthConfig.humanitarianText.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                AuthConfig.humanitarianText,
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: AppTheme.getTextSecondary(context),
                                ),
                              ),
                            ],

                            if (AuthConfig.humanitarianLearnMoreUrl.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.tryParse(AuthConfig.humanitarianLearnMoreUrl);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'En savoir plus',
                                        style: AppFonts.primary(
                                          context,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF088839),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 12,
                                        color: Color(0xFF088839),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Fixed Pinned Bottom Bar with Payment Button & Security Badge
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                        backgroundColor: const Color(0xFF088839),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        IconlyLight.shield_done,
                        size: 13,
                        color: Color(0xFF088839),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Powered by Stripe & PayPal • 256-Bit SSL Encrypted',
                          textAlign: TextAlign.center,
                          style: AppFonts.primary(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.getTextSecondary(context),
                          ),
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
