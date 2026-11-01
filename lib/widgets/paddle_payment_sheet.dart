import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/auth_config.dart';
import '../screens/paddle_checkout_screen.dart';
import '../theme/app_fonts.dart';
import '../theme/app_theme.dart';

/// Professional, PCI-compliant in-app Bottom Sheet that embeds Paddle Billing
/// directly within the application, featuring a native JavaScript bridge,
/// skeleton loading states, and external browser fallback.
class PaddlePaymentSheet extends StatefulWidget {
  final String checkoutUrl;
  final String? transactionId;
  final double amount;
  final String currency;
  final String tier;

  const PaddlePaymentSheet({
    super.key,
    required this.checkoutUrl,
    this.transactionId,
    required this.amount,
    this.currency = 'EUR',
    this.tier = 'COMMUNITY',
  });

  /// Forwarded to PaddleCheckoutScreen full screen interface.
  static Future<bool?> show(
    BuildContext context, {
    required String checkoutUrl,
    String? transactionId,
    required double amount,
    String currency = 'EUR',
    String tier = 'COMMUNITY',
    String? userEmail,
    String? userName,
  }) {
    return PaddleCheckoutScreen.push(
      context,
      checkoutUrl: checkoutUrl,
      transactionId: transactionId,
      amount: amount,
      currency: currency,
      tier: tier,
      userEmail: userEmail,
      userName: userName,
    );
  }

  @override
  State<PaddlePaymentSheet> createState() => _PaddlePaymentSheetState();
}

class _PaddlePaymentSheetState extends State<PaddlePaymentSheet> {
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

  /// Extracts transaction ID from either the direct prop or the checkout URL parameters.
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
            // Ignore minor subresource or background image failures
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

  /// Processes bidirectional events received directly from Paddle.js in WebView.
  void _onBridgeMessage(String rawJson) {
    try {
      final data = jsonDecode(rawJson) as Map<String, dynamic>;
      final event = data['event']?.toString();
      final payload = data['data'] as Map<String, dynamic>?;

      debugPrint('[PaddleBridge] Event received: $event');

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
            'Paddle checkout encountered an issue.';
        if (mounted) {
          setState(() => _errorMessage = msg);
        }
      }
    } catch (e) {
      debugPrint('[PaddleBridge] Error parsing event: $e');
    }
  }

  /// Detects success and cancellation redirect triggers from URLs.
  bool _handleRedirect(String url) {
    if (_isRedirecting) return true;
    final lower = url.toLowerCase();

    // Success indicators
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

    // Cancel / Exit indicators
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

  /// Generates the self-contained, high-performance HTML hosting Paddle.js.
  String _generatePaddleCheckoutHtml(String txnId) {
    final isLive = AuthConfig.paddleMode == 'live';
    final token = AuthConfig.paddleClientToken.isNotEmpty
        ? AuthConfig.paddleClientToken
        : 'test_ce1cedc75f9a35f3708af85800f';

    return '''
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Paddle Secure Checkout</title>
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
      min-height: 480px;
      margin: 0 auto;
    }
    .state-wrapper {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 40px 16px;
      text-align: center;
    }
    .spinner-ring {
      width: 36px;
      height: 36px;
      border: 3px solid rgba(8, 136, 57, 0.15);
      border-top-color: #088839;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin-bottom: 14px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .loading-title {
      font-size: 14px;
      font-weight: 600;
      color: #1f2937;
      margin-bottom: 4px;
    }
    .loading-desc {
      font-size: 12px;
      color: #6b7280;
    }
    .error-card {
      background: #fef2f2;
      border: 1px solid #fee2e2;
      border-radius: 12px;
      padding: 16px;
      margin: 20px;
      color: #991b1b;
      font-size: 13px;
      line-height: 1.4;
      text-align: center;
    }
  </style>
</head>
<body>
  <div id="loading" class="state-wrapper">
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

        Paddle.Checkout.open({
          transactionId: '$txnId',
          settings: {
            displayMode: 'inline',
            frameTarget: 'paddle-checkout-container',
            frameInitialHeight: 480,
            frameStyle: 'width: 100%; min-width: 100%; background-color: transparent; border: none;',
            successUrl: 'https://allohalal.fr/payment-success?txn_id=$txnId'
          }
        });
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
    String targetUrl = widget.checkoutUrl;

    if (targetUrl.contains('localhost') || targetUrl.contains('127.0.0.1')) {
      final isLive = AuthConfig.paddleMode == 'live';
      final baseUrl = isLive ? 'https://buy.paddle.com' : 'https://sandbox-buy.paddle.com';
      targetUrl = '$baseUrl/checkout/build?txn_id=$effectiveTxnId';
    }

    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
            // Top Drag Handle & Verified Brand Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 14, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppTheme.getTextSecondary(context).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF088839).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          IconlyBold.shield_done,
                          color: Color(0xFF088839),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Paddle Secure Checkout',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.primary(
                                      context,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                                if (AuthConfig.paddleMode.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF088839).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      AuthConfig.paddleMode.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF088839),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.amount.toStringAsFixed(2)} ${widget.currency == 'EUR' ? '€' : widget.currency} • SSL 256-Bit • Sans abonnement',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.primary(
                                context,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          size: 21,
                        ),
                        tooltip: 'Ouvrir dans le navigateur',
                        color: AppTheme.getTextSecondary(context),
                        onPressed: _openInExternalBrowser,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 22,
                        ),
                        tooltip: 'Fermer',
                        color: AppTheme.getTextSecondary(context),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Colors.black12),

            // Embedded Payment Surface
            Expanded(
              child: Stack(
                children: [
                  // 1. Primary WebView with Paddle Iframe
                  if (_errorMessage == null)
                    WebViewWidget(controller: _controller),

                  // 2. Native Premium Loading Skeleton State
                  if (_isLoading && !_isSdkReady && _errorMessage == null)
                    Container(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          const CircularProgressIndicator(
                            color: Color(0xFF088839),
                            strokeWidth: 2.8,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Sécurisation de la passerelle...',
                            style: AppFonts.primary(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chargement des options de paiement sécurisées Paddle',
                            style: AppFonts.primary(
                              context,
                              fontSize: 12,
                              color: AppTheme.getTextSecondary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          // Skeleton form cards simulating card inputs
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF088839).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3. Error Fallback Card
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
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Impossible de charger la passerelle',
                              style: AppFonts.primary(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: AppFonts.primary(
                                context,
                                fontSize: 12.5,
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
          ],
        ),
      ),
    );
  }
}
