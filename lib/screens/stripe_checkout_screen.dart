import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/stripe_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Full-screen, secure Stripe Checkout interface.
class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String? sessionId;
  final double amount;
  final String tier;
  final String? userEmail;
  final String? userName;

  const StripeCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    this.sessionId,
    required this.amount,
    required this.tier,
    this.userEmail,
    this.userName,
  });

  /// Static helper to navigate directly to Stripe Checkout Screen.
  static Future<bool?> push(
    BuildContext context, {
    required String checkoutUrl,
    String? sessionId,
    required double amount,
    required String tier,
    String? userEmail,
    String? userName,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StripeCheckoutScreen(
          checkoutUrl: checkoutUrl,
          sessionId: sessionId,
          amount: amount,
          tier: tier,
          userEmail: userEmail,
          userName: userName,
        ),
      ),
    );
  }

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
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
            if (error.isForMainFrame == false) return;
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
        lower.contains('status=success') ||
        lower.contains('checkout/success')) {
      _isRedirecting = true;
      if (widget.sessionId != null) {
        StripeService.instance.syncCompletedTransaction(widget.sessionId!);
      }
      Future.microtask(() {
        if (mounted) Navigator.pop(context, true);
      });
      return true;
    }

    if (lower.contains('payment-cancelled') || lower.contains('cancel=true')) {
      _isRedirecting = true;
      Future.microtask(() {
        if (mounted) Navigator.pop(context, false);
      });
      return true;
    }

    return false;
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(IconlyBold.danger, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 10),
            Text(
              'Annuler le paiement ?',
              style: AppFonts.primary(dialogCtx, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment quitter la page de paiement sécurisé Stripe ?',
          style: AppFonts.secondary(dialogCtx, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Continuer',
              style: AppFonts.primary(dialogCtx, fontWeight: FontWeight.w700, color: const Color(0xFF635BFF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(
              'Quitter',
              style: AppFonts.primary(dialogCtx, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            tooltip: 'Annuler',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context, false);
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(IconlyBold.shield_done, color: Color(0xFF635BFF), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Stripe',
                      style: TextStyle(
                        color: Color(0xFF635BFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Paiement Sécurisé',
                  style: AppFonts.primary(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Text(
                  '${widget.amount.toStringAsFixed(2)} €',
                  style: AppFonts.primary(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF088839),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(IconlyBold.danger, color: Color(0xFFEF4444), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Erreur de chargement',
                        style: AppFonts.primary(context, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppFonts.secondary(context, fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _controller.reload();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF635BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            else
              WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: Colors.white.withValues(alpha: 0.9),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF635BFF)),
                        strokeWidth: 2.5,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Connexion sécurisée à Stripe...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

