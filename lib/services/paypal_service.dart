import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/auth_config.dart';
import 'contribution_email_service.dart';

class PaypalSessionResult {
  final bool success;
  final String? url;
  final String? orderId;
  final String message;
  final bool isDirectLink;

  const PaypalSessionResult({
    required this.success,
    this.url,
    this.orderId,
    required this.message,
    this.isDirectLink = false,
  });

  String? get transactionId => orderId;
}

/// Service to handle PayPal Payment operations for free-will contributions.
class PaypalService {
  PaypalService._();

  static final PaypalService instance = PaypalService._();

  /// Creates a PayPal Order session and returns the approval URL.
  Future<PaypalSessionResult> createPaypalSession({
    required double amount,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    if (!AuthConfig.isPaypalEnabled) {
      return const PaypalSessionResult(
        success: false,
        message: 'PayPal payments are currently disabled.',
      );
    }

    if (amount <= 0) {
      return const PaypalSessionResult(
        success: false,
        message: 'Invalid contribution amount.',
      );
    }

    // 1. First attempt: Call Backend API to securely create the PayPal Order
    try {
      final backendUri = Uri.parse('${AppConfig.serverOrigin}/api/paypal/create-order');
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
              'returnUrl': '${AppConfig.serverOrigin}/payment-success?provider=paypal',
              'cancelUrl': '${AppConfig.serverOrigin}/payment-cancelled?provider=paypal',
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (backendResponse.statusCode >= 200 && backendResponse.statusCode < 300) {
        final data = jsonDecode(backendResponse.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          final orderId = data['orderId']?.toString() ?? data['transactionId']?.toString();
          final url = data['url'].toString();

          _recordContributionToSupabase(
            amount: amount,
            tier: tier ?? 'COMMUNITY',
            transactionId: orderId,
            donorName: donorName,
            donorEmail: donorEmail,
            message: message,
          );

          return PaypalSessionResult(
            success: true,
            url: url,
            orderId: orderId,
            message: 'PayPal session created.',
            isDirectLink: data['isDirectLink'] == true,
          );
        }
      }
    } catch (_) {
      // Backend not reached, fall back
    }

    // 2. Direct Fallback: PayPal.me URL if configured
    final paypalMe = AuthConfig.paypalMeUrl.trim();
    if (paypalMe.isNotEmpty) {
      final cleanMe = paypalMe.replaceAll(RegExp(r'/+$'), '');
      final baseMe = cleanMe.contains('http') ? cleanMe : 'https://paypal.me/$cleanMe';
      final currency = AuthConfig.paypalCurrency.toUpperCase();
      final url = '$baseMe/${amount.toStringAsFixed(2)}$currency';
      final orderId = 'pp_${DateTime.now().millisecondsSinceEpoch}';

      _recordContributionToSupabase(
        amount: amount,
        tier: tier ?? 'COMMUNITY',
        transactionId: orderId,
        donorName: donorName,
        donorEmail: donorEmail,
        message: message,
      );

      return PaypalSessionResult(
        success: true,
        url: url,
        orderId: orderId,
        message: 'PayPal direct link generated.',
        isDirectLink: true,
      );
    }

    return const PaypalSessionResult(
      success: false,
      message: 'Could not initialize PayPal checkout. Please verify credentials or try Stripe.',
    );
  }

  /// Automatically records the transaction to Supabase
  Future<void> recordContribution({
    required double amount,
    required String tier,
    String? transactionId,
    String? donorName,
    String? donorEmail,
    String? message,
  }) async {
    await _recordContributionToSupabase(
      amount: amount,
      tier: tier,
      transactionId: transactionId,
      donorName: donorName,
      donorEmail: donorEmail,
      message: message,
    );

    ContributionEmailService.instance.sendContributionEmails(
      donorEmail: donorEmail,
      donorName: donorName,
      amount: amount,
      currency: AuthConfig.paypalCurrency.toUpperCase(),
      tier: tier,
      transactionId: transactionId,
      paymentMethod: 'PayPal',
    );
  }

  /// Internal Supabase logging
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
        'currency': AuthConfig.paypalCurrency.toUpperCase(),
        'tier': validTier,
        'payment_method': 'PAYPAL',
        'transaction_id': transactionId ?? contribId,
        'message': message ?? 'Community Contribution via Allo Halal App',
        'status': 'COMPLETED',
        'is_anonymous': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await http
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

      // Trigger backend confirmation to send transactional emails (donor confirmation & admin alert)
      try {
        final confirmUri = Uri.parse('${AppConfig.serverOrigin}/api/payment/confirm');
        await http.post(
          confirmUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transactionId': transactionId ?? contribId,
            'provider': 'PAYPAL',
            'amount': amount,
            'currency': AuthConfig.paypalCurrency.toUpperCase(),
            'donorName': donorName ?? '',
            'donorEmail': donorEmail ?? '',
            'tier': validTier,
          }),
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[PaypalService] Supabase log error: $e');
    }
  }

  /// Syncs transaction details with backend after successful completion
  Future<void> syncCompletedTransaction(String transactionId) async {
    try {
      final serverUri = Uri.parse('${AppConfig.serverOrigin}/api/payment/confirm');
      await http.post(
        serverUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transactionId': transactionId,
          'provider': 'PAYPAL',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

