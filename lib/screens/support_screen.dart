import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/auth_config.dart';
import '../services/auth_service.dart';
import '../services/paddle_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';
import 'paddle_checkout_screen.dart';

/// Full-screen, high-fidelity Support & Free-will Contribution screen ("Prix libre").
/// Replaces the legacy modal bottom sheet with a spacious, keyboard-friendly,
/// dedicated native screen with sliders, presets, and direct Paddle Billing integration.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  /// Helper to push the SupportScreen onto navigation stack.
  static Future<void> push(BuildContext context) {
    if (!AuthConfig.isContributionsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contributions are currently disabled.'),
        ),
      );
      return Future.value();
    }
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => const SupportScreen(),
      ),
    );
  }

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late double _contributionAmount;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _contributionAmount = AuthConfig.defaultContributionAmount.clamp(
      AuthConfig.minContributionAmount,
      AuthConfig.maxContributionAmount,
    );
    // Refresh live configuration from Supabase immediately on mount
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

    if (!AuthConfig.isPaddleEnabled) {
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

      // Automatically prefill user's email and name if logged in
      final user = AuthService.instance.currentUser;
      final donorEmail = user?.email.trim() ?? '';
      final donorName = (user?.name.trim().isNotEmpty == true)
          ? user!.name.trim()
          : (user?.username.trim().isNotEmpty == true ? user!.username.trim() : '');

      final sessionResult = await PaddleService.instance.createPaddleSession(
        amount: _contributionAmount,
        tier: tierName,
        donorName: donorName.isNotEmpty ? donorName : null,
        donorEmail: donorEmail.isNotEmpty ? donorEmail : null,
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

      // Open the dedicated Paddle Checkout Screen
      final paid = await PaddleCheckoutScreen.push(
        context,
        checkoutUrl: sessionResult.url!,
        transactionId: sessionResult.transactionId,
        amount: _contributionAmount,
        tier: tierName,
        userEmail: donorEmail.isNotEmpty ? donorEmail : null,
        userName: donorName.isNotEmpty ? donorName : null,
      );

      if (!mounted) return;

      if (paid == true) {
        if (sessionResult.transactionId != null) {
          PaddleService.instance.syncCompletedTransaction(sessionResult.transactionId!);
        }
        Navigator.pop(context); // Return back to Settings
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.getBackgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(IconlyLight.arrow_left),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AuthConfig.contributionTitle.isNotEmpty
              ? AuthConfig.contributionTitle
              : 'support.title'.tr(),
          style: AppFonts.primary(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.getTextPrimary(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '★ Prix libre',
                  style: TextStyle(
                    color: Color(0xFFD97706),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Card (Amber, Gold & Warm Green Accent)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                      : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
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
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
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
                              AuthConfig.contributionTitle.isNotEmpty
                                  ? AuthConfig.contributionTitle
                                  : 'support.title'.tr(),
                              style: AppFonts.primary(
                                context,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              AuthConfig.contributionSubtitle.isNotEmpty
                                  ? AuthConfig.contributionSubtitle
                                  : 'support.no_commitment'.tr(),
                              style: AppFonts.primary(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF088839),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AuthConfig.contributionDesc.isNotEmpty
                        ? AuthConfig.contributionDesc
                        : 'support.desc'.tr(),
                    style: AppFonts.primary(
                      context,
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Big Amount Display Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF241B0E), const Color(0xFF112318)]
                      : [const Color(0xFFFFFBEB), const Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
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
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF088839),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF088839),
                inactiveTrackColor: AppTheme.getBorderColor(context),
                thumbColor: const Color(0xFF088839),
                overlayColor: const Color(0xFF088839).withValues(alpha: 0.15),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
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
            const SizedBox(height: 12),

            // Preset Amount Buttons (Dynamic Wrap)
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF088839)
                            : AppTheme.getCardColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF088839)
                              : AppTheme.getBorderColor(context),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF088839).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        amountText,
                        style: AppFonts.primary(
                          context,
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

            // Humanitarian Commitment & Solidarity Card
            if (AuthConfig.isHumanitarianCommitmentEnabled) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Icon, Title and Share Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            IconlyBold.shield_done,
                            color: Color(0xFF088839),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AuthConfig.humanitarianTitle,
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),
                              if (AuthConfig.humanitarianBadge.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF088839).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    AuthConfig.humanitarianBadge,
                                    style: const TextStyle(
                                      color: Color(0xFF088839),
                                      fontSize: 10,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              AuthConfig.humanitarianCharityShare,
                              style: AppFonts.primary(
                                context,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF088839),
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (AuthConfig.humanitarianOrganizationName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(IconlyLight.heart, size: 14, color: Color(0xFF088839)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AuthConfig.humanitarianOrganizationName,
                              style: AppFonts.primary(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF088839),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (AuthConfig.humanitarianText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        AuthConfig.humanitarianText,
                        style: AppFonts.primary(
                          context,
                          fontSize: 12,
                          height: 1.45,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                    ],

                    if (AuthConfig.humanitarianLearnMoreUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(AuthConfig.humanitarianLearnMoreUrl);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'En savoir plus',
                                style: AppFonts.primary(
                                  context,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF088839),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
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

            const SizedBox(height: 24),

            // Trust & Security Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  'Paiement sécurisé via Paddle • Chiffré SSL 256 bits',
                  style: AppFonts.primary(
                    context,
                    fontSize: 11.5,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: AppTheme.getBorderColor(context),
              width: 1,
            ),
          ),
        ),
        child: SizedBox(
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

