import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/auth_config.dart';

class StripeSessionResult {
  final bool success;
  final String? url;
  final String? sessionId;
  final String message;

  const StripeSessionResult({
    required this.success,
    this.url,
    this.sessionId,
    required this.message,
  });
}

/// Service to handle Stripe Payment Gateway operations for community contributions.
/// Resilient direct Stripe REST API execution for in-app bottom sheet checkout
/// and auto-syncs transaction records directly to Supabase.
class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  /// Creates a Stripe Checkout session and returns the hosted URL for in-app bottom sheet display.
  Future<StripeSessionResult> createStripeSession({
    required double amount,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    if (!AuthConfig.isStripeEnabled) {
      return const StripeSessionResult(
        success: false,
        message: 'Stripe payments are currently disabled.',
      );
    }

    if (amount <= 0) {
      return const StripeSessionResult(
        success: false,
        message: 'Invalid contribution amount.',
      );
    }

    final secretKey = AuthConfig.stripeSecretKey;
    if (secretKey.isEmpty) {
      return const StripeSessionResult(
        success: false,
        message: 'Stripe API key is not configured.',
      );
    }

    try {
      final endpoint = Uri.parse('https://api.stripe.com/v1/checkout/sessions');
      final unitAmount = (amount * 100).toInt();

      final body = {
        'mode': 'payment',
        'payment_method_types[0]': 'card',
        'line_items[0][price_data][currency]': AuthConfig.stripeCurrency.toLowerCase(),
        'line_items[0][price_data][unit_amount]': unitAmount.toString(),
        'line_items[0][price_data][product_data][name]': 'Support Allo Halal ($tier)',
        'line_items[0][price_data][product_data][description]':
            'Free-will community contribution (Prix libre) - Allo Halal',
        'line_items[0][quantity]': '1',
        'metadata[donor_name]': donorName ?? 'Allo Halal Mobile Supporter',
        'metadata[donor_email]': donorEmail ?? '',
        'metadata[tier]': tier ?? 'COMMUNITY',
        'metadata[message]': message ?? '',
        'success_url': 'https://allohalal.fr/payment-success?session_id={CHECKOUT_SESSION_ID}',
        'cancel_url': 'https://allohalal.fr/payment-cancelled',
      };

      final response = await http
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $secretKey',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sessionUrl = data['url'] as String?;
        final sessionId = data['id'] as String?;

        if (sessionUrl != null && sessionUrl.isNotEmpty) {
          // Record contribution into Supabase in background
          _recordContributionToSupabase(
            amount: amount,
            tier: tier ?? 'COMMUNITY',
            sessionId: sessionId,
            donorName: donorName,
            donorEmail: donorEmail,
            message: message,
          );

          return StripeSessionResult(
            success: true,
            url: sessionUrl,
            sessionId: sessionId,
            message: 'Session created successfully.',
          );
        }
      }

      final rawBody = response.body.trim();
      if (rawBody.startsWith('{')) {
        try {
          final errorData = jsonDecode(rawBody) as Map<String, dynamic>;
          final errMsg = errorData['error']?['message'] ?? 'Stripe error (${response.statusCode})';
          return StripeSessionResult(success: false, message: errMsg.toString());
        } catch (_) {}
      }

      return StripeSessionResult(
        success: false,
        message: 'Could not create payment session (${response.statusCode}).',
      );
    } catch (e) {
      return StripeSessionResult(
        success: false,
        message: 'Network error connecting to payment gateway: $e',
      );
    }
  }

  /// Automatically records the transaction to Supabase so it immediately appears in Contributions History.
  Future<void> _recordContributionToSupabase({
    required double amount,
    required String tier,
    String? sessionId,
    String? donorName,
    String? donorEmail,
    String? message,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/contributions');
      final contribId = (sessionId != null && sessionId.isNotEmpty)
          ? sessionId
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
        'currency': AuthConfig.stripeCurrency.toUpperCase(),
        'tier': validTier,
        'payment_method': 'STRIPE',
        'transaction_id': sessionId ?? contribId,
        'stripe_session_id': sessionId ?? contribId,
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
        print(
          '[StripeService] Contribution logged to Supabase server: HTTP ${response.statusCode} (id: $contribId)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[StripeService] Supabase log error: $e');
      }
    }
  }

  /// Syncs customer details (name, email, country) directly from Stripe to Supabase after successful payment.
  Future<void> syncCompletedSession(String sessionId) async {
    try {
      final secretKey = AuthConfig.stripeSecretKey;
      if (secretKey.isEmpty) return;

      final res = await http.get(
        Uri.parse('https://api.stripe.com/v1/checkout/sessions/$sessionId'),
        headers: {'Authorization': 'Bearer $secretKey'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final cust = data['customer_details'] as Map<String, dynamic>?;
        final name = cust?['name'] as String?;
        final email = cust?['email'] as String?;
        final country = (cust?['address'] as Map<String, dynamic>?)?['country'] as String?;
        final amountTotal = data['amount_total'] as num?;
        final currency = data['currency'] as String?;

        final uri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/contributions?id=eq.$sessionId');
        final patchData = <String, dynamic>{
          'status': 'COMPLETED',
        };
        if (name != null && name.trim().isNotEmpty) patchData['donor_name'] = name.trim();
        if (email != null && email.trim().isNotEmpty) patchData['donor_email'] = email.trim();
        if (country != null && country.trim().isNotEmpty) patchData['donor_location'] = country.trim();
        if (amountTotal != null) patchData['amount'] = amountTotal / 100.0;
        if (currency != null) patchData['currency'] = currency.toUpperCase();

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
          print('[StripeService] Synced customer details to Supabase for session: $sessionId ($name)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[StripeService] syncCompletedSession error: $e');
      }
    }
  }
}
