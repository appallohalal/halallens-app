import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/auth_config.dart';
import '../screens/paypal_checkout_screen.dart';
import '../screens/stripe_checkout_screen.dart';
import '../services/auth_service.dart';
import '../services/paypal_service.dart';
import '../services/stripe_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

enum PaymentMethodType { stripe, paypal }

/// Sleek Bottom Sheet with official Stripe and PayPal SVG wordmark cards.
class PaymentMethodBottomSheet extends StatefulWidget {
  final double amount;
  final String tier;
  final String? donorName;
  final String? donorEmail;
  final String? message;

  const PaymentMethodBottomSheet({
    super.key,
    required this.amount,
    required this.tier,
    this.donorName,
    this.donorEmail,
    this.message,
  });

  /// Static helper to display the Payment Method selection Bottom Sheet.
  static Future<bool?> show(
    BuildContext context, {
    required double amount,
    required String tier,
    String? donorName,
    String? donorEmail,
    String? message,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodBottomSheet(
        amount: amount,
        tier: tier,
        donorName: donorName,
        donorEmail: donorEmail,
        message: message,
      ),
    );
  }

  @override
  State<PaymentMethodBottomSheet> createState() => _PaymentMethodBottomSheetState();
}

class _PaymentMethodBottomSheetState extends State<PaymentMethodBottomSheet> {
  PaymentMethodType _selectedMethod = PaymentMethodType.stripe;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!AuthConfig.isStripeEnabled && AuthConfig.isPaypalEnabled) {
      _selectedMethod = PaymentMethodType.paypal;
    } else {
      _selectedMethod = PaymentMethodType.stripe;
    }
  }

  String _resolveDonorEmail() {
    if (widget.donorEmail != null && widget.donorEmail!.trim().isNotEmpty) {
      return widget.donorEmail!.trim();
    }
    final user = AuthService.instance.currentUser;
    return user?.email.trim() ?? '';
  }

  String _resolveDonorName() {
    if (widget.donorName != null && widget.donorName!.trim().isNotEmpty) {
      return widget.donorName!.trim();
    }
    final user = AuthService.instance.currentUser;
    if (user?.name.trim().isNotEmpty == true) return user!.name.trim();
    if (user?.username.trim().isNotEmpty == true) return user!.username.trim();
    return 'Allo Halal Supporter';
  }

  Future<void> _proceedWithPayment() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final donorEmail = _resolveDonorEmail();
    final donorName = _resolveDonorName();

    try {
      if (_selectedMethod == PaymentMethodType.stripe) {
        // Native Stripe PaymentSheet (as instructed by Stripe integration guide)
        final result = await StripeService.instance.payWithPaymentSheet(
          amount: widget.amount,
          donorName: donorName,
          donorEmail: donorEmail,
          tier: widget.tier,
          message: widget.message ?? 'Contribution libre Allo Halal',
        );

        if (!mounted) return;

        if (result.success) {
          Navigator.pop(context, true);
          return;
        } else if (result.isCancelled) {
          return;
        } else {
          // If keys are not configured or invalid, show the clear message immediately
          final pubKey = AuthConfig.stripePublishableKey.trim();
          final secKey = AuthConfig.stripeSecretKey.trim();
          if (pubKey.isEmpty || secKey.isEmpty || !pubKey.startsWith('pk_') || !secKey.startsWith('sk_')) {
            setState(() {
              _errorMessage = result.message;
            });
            return;
          }

          // If native sheet fails (e.g. simulator or sandbox fallback), fallback to web checkout
          final session = await StripeService.instance.createStripeSession(
            amount: widget.amount,
            donorName: donorName,
            donorEmail: donorEmail,
            tier: widget.tier,
            message: widget.message ?? 'Contribution libre Allo Halal',
          );

          if (!mounted) return;

          if (session.success && session.url != null) {
            final paid = await StripeCheckoutScreen.push(
              context,
              checkoutUrl: session.url!,
              sessionId: session.sessionId,
              amount: widget.amount,
              tier: widget.tier,
              userEmail: donorEmail,
              userName: donorName,
            );
            if (mounted && paid == true) {
              Navigator.pop(context, true);
              return;
            }
          } else {
            setState(() {
              _errorMessage = result.message;
            });
          }
        }
      } else {
        // PayPal Checkout View (as instructed by Mahmoud Elbanna's Medium guide)
        final clientId = AuthConfig.paypalClientId.trim();
        final secretKey = AuthConfig.paypalSecretKey.trim();

        if (clientId.isNotEmpty && secretKey.isNotEmpty) {
          final currency = AuthConfig.paypalCurrency.toUpperCase();
          final formattedAmount = widget.amount.toStringAsFixed(2);

          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext ctx) => PaypalCheckoutView(
                sandboxMode: AuthConfig.paypalMode != 'live',
                clientId: clientId,
                secretKey: secretKey,
                transactions: [
                  {
                    "amount": {
                      "total": formattedAmount,
                      "currency": currency,
                      "details": {
                        "subtotal": formattedAmount,
                        "shipping": '0',
                        "shipping_discount": 0,
                      }
                    },
                    "description": "Contribution libre Allo Halal (${widget.tier})",
                    "item_list": {
                      "items": [
                        {
                          "name": "Soutien Allo Halal (${widget.tier})",
                          "quantity": 1,
                          "price": formattedAmount,
                          "currency": currency,
                        }
                      ]
                    }
                  }
                ],
                note: "Merci pour votre contribution à Allo Halal.",
                onSuccess: (Map params) async {
                  final paymentId = params['data']?['id']?.toString() ??
                      params['paymentId']?.toString() ??
                      'pp_${DateTime.now().millisecondsSinceEpoch}';

                  await PaypalService.instance.recordContribution(
                    amount: widget.amount,
                    tier: widget.tier,
                    transactionId: paymentId,
                    donorName: donorName,
                    donorEmail: donorEmail,
                    message: widget.message,
                  );

                  PaypalService.instance.syncCompletedTransaction(paymentId);
                  if (mounted) Navigator.pop(context, true);
                },
                onError: (error) {
                  if (mounted) {
                    setState(() {
                      _errorMessage = 'Erreur PayPal: $error';
                    });
                  }
                },
                onCancel: () {
                  // User cancelled
                },
              ),
            ),
          );
        } else {
          // Fallback to PayPal session URL or PayPal.me link
          final session = await PaypalService.instance.createPaypalSession(
            amount: widget.amount,
            donorName: donorName,
            donorEmail: donorEmail,
            tier: widget.tier,
            message: widget.message ?? 'Contribution libre Allo Halal',
          );

          if (!mounted) return;

          if (!session.success || session.url == null) {
            setState(() {
              _errorMessage = session.message;
              _isProcessing = false;
            });
            return;
          }

          if (session.isDirectLink) {
            final uri = Uri.parse(session.url!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (!mounted) return;
              Navigator.pop(context, true);
            } else {
              setState(() {
                _errorMessage = 'Impossible d\'ouvrir le lien PayPal.';
              });
            }
          } else {
            final paid = await PaypalCheckoutScreen.push(
              context,
              checkoutUrl: session.url!,
              orderId: session.orderId,
              amount: widget.amount,
              tier: widget.tier,
              userEmail: donorEmail,
              userName: donorName,
            );

            if (!mounted) return;
            if (paid == true) {
              Navigator.pop(context, true);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Une erreur est survenue: $e';
        });
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
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row: Title & Close Button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moyen de paiement',
                        style: AppFonts.primary(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sélectionnez votre moyen de paiement sécurisé',
                        style: AppFonts.secondary(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: secondaryTextColor,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Fermer',
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Amount Summary Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF064E3B).withValues(alpha: 0.5), const Color(0xFF022C22).withValues(alpha: 0.5)]
                      : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF088839), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      IconlyBold.heart,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Montant de votre contribution',
                          style: AppFonts.secondary(
                            context,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Sans engagement • Paiement unique',
                          style: AppFonts.secondary(
                            context,
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${widget.amount.toStringAsFixed(2)} €',
                    style: AppFonts.primary(
                      context,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF088839),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(IconlyBold.danger, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppFonts.secondary(
                          context,
                          fontSize: 12,
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Payment Option 1: Stripe SVG Wordmark
            _buildSvgPaymentOption(
              context: context,
              method: PaymentMethodType.stripe,
              svgAsset: 'assets/stripe_wordmark.svg',
              svgHeight: 32,
              brandColor: const Color(0xFF635BFF),
              isSelected: _selectedMethod == PaymentMethodType.stripe,
              borderColor: borderColor,
              cardBg: cardBg,
              isDark: isDark,
            ),

            const SizedBox(height: 14),

            // Payment Option 2: PayPal SVG Wordmark
            _buildSvgPaymentOption(
              context: context,
              method: PaymentMethodType.paypal,
              svgAsset: 'assets/paypal-wordmark.svg',
              svgHeight: 30,
              brandColor: const Color(0xFF003087),
              isSelected: _selectedMethod == PaymentMethodType.paypal,
              borderColor: borderColor,
              cardBg: cardBg,
              isDark: isDark,
            ),

            const SizedBox(height: 22),

            // Primary Pay Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _proceedWithPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedMethod == PaymentMethodType.stripe
                      ? const Color(0xFF635BFF)
                      : const Color(0xFF003087),
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
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Payer ${widget.amount.toStringAsFixed(2)} € avec ${_selectedMethod == PaymentMethodType.stripe ? "Stripe" : "PayPal"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.primary(
                                context,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 14),

            // Trust & Security Notice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Chiffrement SSL 256 bits • Don sécurisé sans prélèvement futur',
                    textAlign: TextAlign.center,
                    style: AppFonts.primary(
                      context,
                      fontSize: 11,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgPaymentOption({
    required BuildContext context,
    required PaymentMethodType method,
    required String svgAsset,
    required double svgHeight,
    required Color brandColor,
    required bool isSelected,
    required Color borderColor,
    required Color cardBg,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? brandColor.withValues(alpha: isDark ? 0.14 : 0.05)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? brandColor : borderColor,
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SvgPicture.asset(
                  svgAsset,
                  height: svgHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? brandColor : const Color(0xFF9CA3AF),
                  width: 2,
                ),
                color: isSelected ? brandColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
