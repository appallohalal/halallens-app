import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../config/auth_config.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// A modern, celebration-themed modal confirmation dialog shown after
/// a successful contribution via Stripe or PayPal.
class ContributionSuccessDialog extends StatelessWidget {
  final double amount;
  final String tier;
  final String? donorName;
  final String? donorEmail;
  final String? transactionId;
  final String paymentMethod;

  const ContributionSuccessDialog({
    super.key,
    required this.amount,
    required this.tier,
    this.donorName,
    this.donorEmail,
    this.transactionId,
    this.paymentMethod = 'Stripe',
  });

  /// Displays the confirmation dialog with an entry bounce animation
  static Future<void> show(
    BuildContext context, {
    required double amount,
    required String tier,
    String? donorName,
    String? donorEmail,
    String? transactionId,
    String paymentMethod = 'Stripe',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ContributionSuccessDialog(
        amount: amount,
        tier: tier,
        donorName: donorName,
        donorEmail: donorEmail,
        transactionId: transactionId,
        paymentMethod: paymentMethod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderLightColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderLightColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Gradient with Icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF088839), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          IconlyBold.shield_done,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Paiement Réussi !',
                      style: AppFonts.primary(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BarakAllahu Fik pour votre générosité',
                      textAlign: TextAlign.center,
                      style: AppFonts.secondary(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFD1FAE5),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Details
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                child: Column(
                  children: [
                    // Contribution Amount Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                IconlyBold.heart,
                                color: Color(0xFF088839),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Montant versé',
                                style: AppFonts.secondary(
                                  context,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF088839),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${amount.toStringAsFixed(2)} €',
                            style: AppFonts.primary(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF088839),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Information List
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderLightColor),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            context: context,
                            label: 'Mode de règlement',
                            value: paymentMethod,
                            isDark: isDark,
                          ),
                          const Divider(height: 16, thickness: 0.6),
                          _buildDetailRow(
                            context: context,
                            label: 'Palier de soutien',
                            value: tier,
                            isDark: isDark,
                          ),
                          if (donorEmail != null && donorEmail!.trim().isNotEmpty) ...[
                            const Divider(height: 16, thickness: 0.6),
                            _buildDetailRow(
                              context: context,
                              label: 'E-mail de confirmation',
                              value: donorEmail!.trim(),
                              isDark: isDark,
                              isEmail: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Humanitarian Commitment Message
                    if (AuthConfig.isHumanitarianCommitmentEnabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF088839).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF088839).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🌱', style: TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '20% de votre contribution sont redistribués à des associations humanitaires pour l\'aide alimentaire.',
                                style: AppFonts.secondary(
                                  context,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF088839),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF088839),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Retour à l\'application',
                          style: AppFonts.primary(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required String label,
    required String value,
    required bool isDark,
    bool isEmail = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.secondary(
            context,
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.primary(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isEmail
                  ? const Color(0xFF0284C7)
                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
          ),
        ),
      ],
    );
  }
}
