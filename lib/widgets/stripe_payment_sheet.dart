import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// An in-app Bottom Sheet that embeds the Stripe Checkout page directly
/// within the application, avoiding any external browser redirects.
class StripePaymentSheet extends StatefulWidget {
  final String checkoutUrl;
  final String? sessionId;
  final double amount;
  final String currency;

  const StripePaymentSheet({
    super.key,
    required this.checkoutUrl,
    this.sessionId,
    required this.amount,
    this.currency = 'EUR',
  });

  /// Displays the embedded Stripe Payment Sheet.
  static Future<bool?> show(
    BuildContext context, {
    required String checkoutUrl,
    String? sessionId,
    required double amount,
    String currency = 'EUR',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // Prevent accidental dismissal during card entry
      backgroundColor: Colors.transparent,
      builder: (context) => StripePaymentSheet(
        checkoutUrl: checkoutUrl,
        sessionId: sessionId,
        amount: amount,
        currency: currency,
      ),
    );
  }

  @override
  State<StripePaymentSheet> createState() => _StripePaymentSheetState();
}

class _StripePaymentSheetState extends State<StripePaymentSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _handleRedirect(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _handleRedirect(url);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_handleRedirect(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  bool _handleRedirect(String url) {
    if (_isRedirecting) return true;
    final lower = url.toLowerCase();
    if (lower.contains('payment-success') ||
        (lower.contains('allohalal.fr') && lower.contains('success'))) {
      _isRedirecting = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return true;
    }
    if (lower.contains('payment-cancelled') ||
        (lower.contains('allohalal.fr') && lower.contains('cancel'))) {
      _isRedirecting = true;
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.92;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppTheme.getTextSecondary(context).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF088839).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          IconlyBold.shield_done,
                          color: Color(0xFF088839),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stripe Secure Checkout',
                              style: AppFonts.primary(
                                context,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              '${widget.amount.toInt()} ${widget.currency == 'EUR' ? '€' : widget.currency} • 256-Bit SSL Encrypted',
                              style: AppFonts.primary(
                                context,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppTheme.getTextSecondary(context),
                          size: 22,
                        ),
                        tooltip: 'Cancel Payment',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Colors.black12),

            // Embedded Stripe WebView
            Expanded(
              child: Stack(
                children: [
                  if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.haramRed,
                              size: 44,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Unable to load payment gateway.',
                              style: AppFonts.primary(
                                context,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppFonts.primary(
                                context,
                                fontSize: 12,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                  _isLoading = true;
                                });
                                _controller.reload();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    WebViewWidget(controller: _controller),

                  if (_isLoading)
                    Container(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF088839),
                              strokeWidth: 2.8,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Connecting to Stripe...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
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
