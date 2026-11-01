import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/auth_config.dart';
import '../services/auth_service.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Full-screen, PCI-compliant Paddle Checkout interface.
/// Provides optimal real estate for payment forms, bank 3D-Secure challenges,
/// keyboard input, and bidirectional JavaScript event handling.
class PaddleCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String? transactionId;
  final double amount;
  final String currency;
  final String tier;
  final String? userEmail;
  final String? userName;

  const PaddleCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    this.transactionId,
    required this.amount,
    this.currency = 'EUR',
    this.tier = 'COMMUNITY',
    this.userEmail,
    this.userName,
  });

  /// Static helper to navigate directly to the Paddle Checkout Screen.
  static Future<bool?> push(
    BuildContext context, {
    required String checkoutUrl,
    String? transactionId,
    required double amount,
    String currency = 'EUR',
    String tier = 'COMMUNITY',
    String? userEmail,
    String? userName,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaddleCheckoutScreen(
          checkoutUrl: checkoutUrl,
          transactionId: transactionId,
          amount: amount,
          currency: currency,
          tier: tier,
          userEmail: userEmail,
          userName: userName,
        ),
      ),
    );
  }

  @override
  State<PaddleCheckoutScreen> createState() => _PaddleCheckoutScreenState();
}

class _PaddleCheckoutScreenState extends State<PaddleCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSdkReady = false;
  String? _errorMessage;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  /// Extracts the transaction ID from the widget property or the checkout URL.
  String _resolveTransactionId() {
    if (widget.transactionId != null && widget.transactionId!.trim().isNotEmpty) {
      return widget.transactionId!.trim();
    }
    try {
      final uri = Uri.parse(widget.checkoutUrl);
      final fromUrl = uri.queryParameters['txn_id'] ??
          uri.queryParameters['_ptxn'] ??
          uri.queryParameters['session_id'];
      if (fromUrl != null && fromUrl.trim().isNotEmpty) {
        return fromUrl.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Automatically resolves the user's email if logged in.
  String _resolveUserEmail() {
    if (widget.userEmail != null && widget.userEmail!.trim().isNotEmpty) {
      return widget.userEmail!.trim();
    }
    final user = AuthService.instance.currentUser;
    if (user != null && user.email.trim().isNotEmpty) {
      return user.email.trim();
    }
    return '';
  }

  /// Initializes the WebViewController with bidirectional JavaScript Bridge.
  void _initWebView() {
    final effectiveTxnId = _resolveTransactionId();
    final isLocalhost = widget.checkoutUrl.contains('localhost') ||
        widget.checkoutUrl.contains('127.0.0.1');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'PaddleBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _onBridgeMessage(message.message);
        },
      )
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
            // Ignore non-mainframe subresource warnings
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
      );

    if (effectiveTxnId.isNotEmpty || isLocalhost) {
      final isLive = AuthConfig.paddleMode == 'live';
      final html = _generatePaddleCheckoutHtml(effectiveTxnId);
      final baseUrl = isLive ? 'https://allohalal.fr' : 'https://localhost:3000';
      _controller.loadHtmlString(html, baseUrl: baseUrl);
    } else {
      _controller.loadRequest(Uri.parse(widget.checkoutUrl));
    }
  }

  /// Handles real-time events sent from Paddle.js inside the WebView.
  void _onBridgeMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final event = data['event']?.toString();
      final payload = data['data'] as Map<String, dynamic>?;

      debugPrint('[PaddleCheckoutScreen] Event: $event');

      if (event == 'checkout.loaded') {
        if (mounted) {
          setState(() {
            _isSdkReady = true;
            _isLoading = false;
          });
        }
      } else if (event == 'checkout.completed') {
        if (_isRedirecting) return;
        _isRedirecting = true;
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (event == 'checkout.closed') {
        if (_isRedirecting) return;
        _isRedirecting = true;
        if (mounted) {
          Navigator.of(context).pop(false);
        }
      } else if (event == 'checkout.error') {
        final msg = payload?['message']?.toString() ??
            payload?['detail']?.toString() ??
            'Erreur lors du traitement du paiement.';
        if (mounted) {
          setState(() => _errorMessage = msg);
        }
      }
    } catch (e) {
      debugPrint('[PaddleCheckoutScreen] Bridge parse error: $e');
    }
  }

  /// Detects HTTP redirects indicating payment completion or cancellation.
  bool _handleRedirect(String url) {
    if (_isRedirecting) return true;
    final lower = url.toLowerCase();

    // Success detection
    if (lower.contains('payment-success') ||
        (lower.contains('allohalal.fr') && lower.contains('success')) ||
        lower.contains('paddle.com/checkout/done') ||
        lower.contains('paddle.com/receipt')) {
      _isRedirecting = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return true;
    }

    // Cancellation detection
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

  /// Generates the self-contained, responsive HTML embedding Paddle.js v2.
  String _generatePaddleCheckoutHtml(String txnId) {
    final isLive = AuthConfig.paddleMode == 'live';
    final token = AuthConfig.paddleClientToken.isNotEmpty
        ? AuthConfig.paddleClientToken
        : 'test_ce1cedc75f9a35f3708af85800f';
    final email = _resolveUserEmail();

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Paiement Sécurisé Paddle</title>
  <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
  <style>
    * {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      min-height: 100%;
      background-color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      overflow-x: hidden;
    }
    .paddle-checkout-container {
      width: 100%;
      min-height: 520px;
      margin: 0 auto;
    }
    .loading-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 20px;
      text-align: center;
    }
    .spinner-ring {
      width: 40px;
      height: 40px;
      border: 3px solid rgba(8, 136, 57, 0.15);
      border-top-color: #088839;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin-bottom: 16px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .loading-title {
      font-size: 15px;
      font-weight: 700;
      color: #111827;
      margin-bottom: 6px;
    }
    .loading-desc {
      font-size: 13px;
      color: #6b7280;
    }
    .error-card {
      background: #fef2f2;
      border: 1px solid #fee2e2;
      border-radius: 12px;
      padding: 18px;
      margin: 24px;
      color: #991b1b;
      font-size: 13px;
      line-height: 1.5;
      text-align: center;
    }
  </style>
</head>
<body>
  <div id="loading" class="loading-state">
    <div class="spinner-ring"></div>
    <div class="loading-title">Sécurisation du paiement...</div>
    <div class="loading-desc">Connexion chiffrée avec la passerelle Paddle</div>
  </div>

  <div class="paddle-checkout-container" id="paddle-checkout-container"></div>

  <script>
    function sendBridge(event, data) {
      try {
        if (window.PaddleBridge) {
          window.PaddleBridge.postMessage(JSON.stringify({
            event: event,
            data: data || {}
          }));
        }
      } catch (e) {
        console.error('Bridge error:', e);
      }
    }

    function initPaddle() {
      try {
        if (typeof Paddle === 'undefined') {
          showError("Impossible de joindre le serveur Paddle CDN. Veuillez vérifier votre connexion Internet.");
          return;
        }

        const isLive = ${isLive ? 'true' : 'false'};
        if (!isLive) {
          Paddle.Environment.set('sandbox');
        }

        Paddle.Initialize({
          token: '$token',
          eventCallback: function(event) {
            console.log('[Paddle Event]', event.name, event.data);
            sendBridge(event.name, event.data);

            if (event.name === 'checkout.loaded') {
              const loader = document.getElementById('loading');
              if (loader) loader.style.display = 'none';
            } else if (event.name === 'checkout.completed') {
              const completedTxn = (event.data && (event.data.transaction_id || event.data.id)) || '$txnId';
              window.location.href = 'https://allohalal.fr/payment-success?txn_id=' + encodeURIComponent(completedTxn);
            } else if (event.name === 'checkout.closed') {
              window.location.href = 'https://allohalal.fr/payment-cancelled';
            }
          }
        });

        const checkoutOptions = {
          transactionId: '$txnId',
          settings: {
            displayMode: 'inline',
            frameTarget: 'paddle-checkout-container',
            frameInitialHeight: 520,
            frameStyle: 'width: 100%; min-width: 100%; background-color: transparent; border: none;',
            successUrl: 'https://allohalal.fr/payment-success?txn_id=$txnId'
          }
        };

        const autoEmail = '$email'.trim();
        if (autoEmail.length > 0) {
          checkoutOptions.customer = {
            email: autoEmail
          };
        }

        Paddle.Checkout.open(checkoutOptions);
      } catch (err) {
        console.error('Paddle open exception:', err);
        showError(err.message || 'Erreur lors du chargement du module de paiement.');
        sendBridge('checkout.error', { message: err.message || String(err) });
      }
    }

    function showError(msg) {
      const loader = document.getElementById('loading');
      if (loader) {
        loader.innerHTML = '<div class="error-card">' + msg + '</div>';
      }
    }

    if (document.readyState === 'loading') {
      window.addEventListener('DOMContentLoaded', initPaddle);
    } else {
      initPaddle();
    }
  </script>
</body>
</html>
''';
  }

  /// Opens the checkout in the external system browser if requested or as a fallback.
  Future<void> _openInExternalBrowser() async {
    final effectiveTxnId = _resolveTransactionId();
    final email = _resolveUserEmail();
    String targetUrl = widget.checkoutUrl;

    if (targetUrl.contains('localhost') || targetUrl.contains('127.0.0.1')) {
      final isLive = AuthConfig.paddleMode == 'live';
      final baseUrl = isLive ? 'https://buy.paddle.com' : 'https://sandbox-buy.paddle.com';
      targetUrl = '$baseUrl/checkout/build?txn_id=$effectiveTxnId';
    }

    if (email.isNotEmpty && !targetUrl.contains('email=')) {
      final sep = targetUrl.contains('?') ? '&' : '?';
      targetUrl = '$targetUrl${sep}_email=${Uri.encodeComponent(email)}';
    }

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  /// Confirms before exiting the payment screen to avoid accidental dismissal.
  Future<bool> _onWillPop() async {
    if (_isRedirecting) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Annuler le paiement ?',
          style: AppFonts.primary(ctx, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir quitter cette page ? Votre contribution ne sera pas débitée.',
          style: AppFonts.primary(ctx, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Continuer',
              style: AppFonts.primary(ctx, color: const Color(0xFF088839), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Quitter',
              style: AppFonts.primary(ctx, color: Colors.redAccent),
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          elevation: 0.5,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(IconlyLight.arrow_left),
            tooltip: 'Retour',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF088839).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  IconlyBold.shield_done,
                  color: Color(0xFF088839),
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Paiement Sécurisé',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.primary(
                              context,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (AuthConfig.paddleMode.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF088839).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AuthConfig.paddleMode.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF088839),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Paddle 256-Bit SSL • Sans abonnement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.primary(
                        context,
                        fontSize: 10.5,
                        color: AppTheme.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Amount badge
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF088839).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF088839).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${widget.amount.toStringAsFixed(2)} ${widget.currency == 'EUR' ? '€' : widget.currency}',
                  style: const TextStyle(
                    color: Color(0xFF088839),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              tooltip: 'Ouvrir dans le navigateur',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: _openInExternalBrowser,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Primary WebView
            if (_errorMessage == null)
              WebViewWidget(controller: _controller),

            // Skeleton Loading Surface
            if (_isLoading && !_isSdkReady && _errorMessage == null)
              Container(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    const CircularProgressIndicator(
                      color: Color(0xFF088839),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sécurisation de la passerelle...',
                      style: AppFonts.primary(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Chargement des options de paiement Paddle',
                      style: AppFonts.primary(
                        context,
                        fontSize: 12.5,
                        color: AppTheme.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Shimmer form blocks
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF088839).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
              ),

            // Error Display Card
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.haramRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: AppTheme.haramRed,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Impossible de charger la passerelle',
                        style: AppFonts.primary(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppFonts.primary(
                          context,
                          fontSize: 13,
                          color: AppTheme.getTextSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openInExternalBrowser,
                              icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                              label: const Text('Navigateur'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _errorMessage = null;
                                  _isLoading = true;
                                  _isSdkReady = false;
                                });
                                _initWebView();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF088839),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Réessayer'),
                            ),
                          ),
                        ],
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

