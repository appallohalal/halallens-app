import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/auth_config.dart';

class PaddleSessionResult {
  final bool success;
  final String? url;
  final String? transactionId;
  final String message;

  const PaddleSessionResult({
    required this.success,
    this.url,
    this.transactionId,
    required this.message,
  });

  // Backward compatibility alias
  String? get sessionId => transactionId;
}

/// Service to handle Paddle Payment Gateway operations for community contributions.
/// Resilient direct Paddle Billing REST API & server proxy execution for in-app bottom sheet checkout,
/// and automatically synchronizes transaction records directly to Supabase.
class PaddleService {
  PaddleService._();

  static final PaddleService instance = PaddleService._();

  /// Creates a Paddle Checkout transaction and returns the hosted URL for in-app bottom sheet display.
  Future<PaddleSessionResult> createPaddleSession({
    required double amount,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    if (!AuthConfig.isPaddleEnabled) {
      return const PaddleSessionResult(
        success: false,
        message: 'Paddle payments are currently disabled.',
      );
    }

    if (amount <= 0) {
      return const PaddleSessionResult(
        success: false,
        message: 'Invalid contribution amount.',
      );
    }

    // 1. First attempt: Use the Backend API to securely create the transaction
    try {
      final backendUri = Uri.parse('${AppConfig.serverOrigin}/api/paddle/create-checkout-session');
      final backendResponse = await http
          .post(
            backendUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amount': amount,
              'donorName': donorName ?? 'Allo Halal Mobile Supporter',
              'donorEmail': donorEmail ?? '',
              'message': message ?? 'Community Contribution via Allo Halal App',
              'tier': tier ?? 'COMMUNITY',
              'returnUrl': '${AppConfig.serverOrigin}/payment-success',
            }),
          )
          .timeout(const Duration(seconds: 7));

      if (backendResponse.statusCode >= 200 && backendResponse.statusCode < 300) {
        final data = jsonDecode(backendResponse.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          final txnId = data['transactionId']?.toString() ?? data['sessionId']?.toString();
          final url = data['url'].toString();

          _recordContributionToSupabase(
            amount: amount,
            tier: tier ?? 'COMMUNITY',
            transactionId: txnId,
            donorName: donorName,
            donorEmail: donorEmail,
            message: message,
          );

          return PaddleSessionResult(
            success: true,
            url: url,
            transactionId: txnId,
            message: 'Paddle transaction initialized.',
          );
        }
      }
    } catch (_) {
      // Backend not reached or offline; proceed to direct fallback
    }

    // 2. Direct Fallback: Create transaction directly on Paddle Billing API if API Key is configured
    String apiKey = AuthConfig.paddleApiKey.trim();
    if (!apiKey.startsWith('pdl_')) {
      if (AuthConfig.paddleMode != 'live') {
        apiKey = 'pdl_sdbx_apikey_01m68jwqg77x4ahhxcqc4bqtjp_MAsCYwrFYN9WZ7MtnHjyx2_AoN';
      } else {
        return const PaddleSessionResult(
          success: false,
          message: 'Invalid Paddle API key configuration. Key must start with "pdl_".',
        );
      }
    }

    try {
      final isLive = AuthConfig.paddleMode == 'live';
      final baseUrl = isLive
          ? 'https://api.paddle.com'
          : 'https://sandbox-api.paddle.com';
      final endpoint = Uri.parse('$baseUrl/transactions');

      final unitAmountMinor = (amount * 100).toInt().toString();
      final currency = AuthConfig.paddleCurrency.toUpperCase();

      final body = {
        'items': [
          {
            'quantity': 1,
            'price': {
              'description': 'Support Allo Halal ($tier)',
              'name': 'Community Contribution',
              'unit_price': {
                'amount': unitAmountMinor,
                'currency_code': currency,
              },
              'product': {
                'name': 'Community Support',
                'tax_category': 'standard',
              },
            },
          }
        ],
        'custom_data': {
          'donor_name': donorName ?? 'Allo Halal Mobile Supporter',
          'donor_email': donorEmail ?? '',
          'tier': tier ?? 'COMMUNITY',
          'message': message ?? '',
          'source': 'Allo Halal Mobile App',
        },
      };

      final response = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Paddle-Version': '1',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final txnData = data['data'] as Map<String, dynamic>?;
        final txnId = txnData?['id'] as String?;
        String? checkoutUrl = (txnData?['checkout'] as Map<String, dynamic>?)?['url'] as String?;

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          if (txnId != null) {
            checkoutUrl = '${AppConfig.serverOrigin}/paddle/checkout?txn_id=$txnId&mode=${AuthConfig.paddleMode}';
          }
        }

        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          _recordContributionToSupabase(
            amount: amount,
            tier: tier ?? 'COMMUNITY',
            transactionId: txnId,
            donorName: donorName,
            donorEmail: donorEmail,
            message: message,
          );

          return PaddleSessionResult(
            success: true,
            url: checkoutUrl,
            transactionId: txnId,
            message: 'Session created successfully.',
          );
        }
      }

      final rawBody = response.body.trim();
      if (rawBody.startsWith('{')) {
        try {
          final errorData = jsonDecode(rawBody) as Map<String, dynamic>;
          final errMsg = errorData['error']?['detail'] ??
              errorData['error']?['message'] ??
              'Paddle error (${response.statusCode})';
          return PaddleSessionResult(success: false, message: errMsg.toString());
        } catch (_) {}
      }

      return PaddleSessionResult(
        success: false,
        message: 'Could not create Paddle transaction (${response.statusCode}).',
      );
    } catch (e) {
      return PaddleSessionResult(
        success: false,
        message: 'Network error connecting to payment gateway: $e',
      );
    }
  }

  /// Automatically records the transaction to Supabase so it immediately appears in Contributions History.
  Future<void> _recordContributionToSupabase({
    required double amount,
    required String tier,
    String? transactionId,
    String? donorName,
    String? donorEmail,
    String? message,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/contributions');
      final contribId = (transactionId != null && transactionId.isNotEmpty)
          ? transactionId
          : 'don_${DateTime.now().millisecondsSinceEpoch}';

      // Ensure tier conforms to server ENUM (COFFEE, SERVER, GROWTH, PATRON)
      final validTier = (tier == 'COFFEE' || tier == 'SERVER' || tier == 'GROWTH' || tier == 'PATRON')
          ? tier
          : (amount <= 2.0
              ? 'COFFEE'
              : amount <= 5.0
                  ? 'SERVER'
                  : amount <= 10.0
                      ? 'GROWTH'
                      : 'PATRON');

      final payload = {
        'id': contribId,
        'donor_name': donorName ?? 'Allo Halal Mobile Supporter',
        'donor_email': donorEmail ?? '',
        'amount': amount,
        'currency': AuthConfig.paddleCurrency.toUpperCase(),
        'tier': validTier,
        'payment_method': 'PADDLE',
        'transaction_id': transactionId ?? contribId,
        'message': message ?? 'Community Contribution via Allo Halal App',
        'status': 'COMPLETED',
        'is_anonymous': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http
          .post(
            uri,
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));

      if (kDebugMode) {
        debugPrint(
          '[PaddleService] Contribution logged to Supabase server: HTTP ${response.statusCode} (id: $contribId)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaddleService] Supabase log error: $e');
      }
    }
  }

  /// Syncs customer details directly from Paddle / server after successful payment.
  Future<void> syncCompletedTransaction(String transactionId) async {
    try {
      // 1. Try server confirmation endpoint
      final serverUri = Uri.parse('${AppConfig.serverOrigin}/api/paddle/confirm-payment');
      try {
        await http
            .post(
              serverUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'transactionId': transactionId}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      // 2. Direct sync to Supabase
      final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/contributions?id=eq.$transactionId');
      final patchData = <String, dynamic>{
        'status': 'COMPLETED',
        'payment_method': 'PADDLE',
      };

      await http.patch(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(patchData),
      );

      if (kDebugMode) {
        debugPrint('[PaddleService] Confirmed transaction in Supabase: $transactionId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PaddleService] syncCompletedTransaction error: $e');
      }
    }
  }
}

