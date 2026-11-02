import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/auth_config.dart';
import 'contribution_email_service.dart';

class StripePaymentResult {
  final bool success;
  final String? paymentIntentId;
  final String message;
  final bool isCancelled;

  const StripePaymentResult({
    required this.success,
    this.paymentIntentId,
    required this.message,
    this.isCancelled = false,
  });
}

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

/// Service to handle native Stripe Payment Sheet operations as documented in
/// the official Flutter Stripe integration guide.
class StripeService {
  StripeService._();

  static final StripeService instance = StripeService._();

  /// Ensures Stripe SDK has latest publishable key applied
  Future<void> initStripe() async {
    try {
      if (AuthConfig.hasValidStripePublishableKey) {
        Stripe.publishableKey = AuthConfig.stripePublishableKey.trim();
        Stripe.merchantIdentifier = 'merchant.com.allohalal';
        await Stripe.instance.applySettings();
      }
    } catch (_) {}
  }

  /// Creates a PaymentIntent and presents native Stripe Payment Sheet
  Future<StripePaymentResult> payWithPaymentSheet({
    required double amount,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    if (!AuthConfig.isStripeEnabled) {
      return const StripePaymentResult(
        success: false,
        message: 'Stripe payments are currently disabled.',
      );
    }

    if (amount <= 0) {
      return const StripePaymentResult(
        success: false,
        message: 'Invalid contribution amount.',
      );
    }

    final pubKey = AuthConfig.stripePublishableKey.trim();
    if (pubKey.isEmpty || (!pubKey.startsWith('pk_test_') && !pubKey.startsWith('pk_live_'))) {
      return const StripePaymentResult(
        success: false,
        message: 'Clé Stripe Publishable non configurée. Veuillez ajouter votre clé Stripe (pk_test_... ou pk_live_...) dans le panneau Admin.',
      );
    }

    try {
      await initStripe();

      // 1. Fetch client_secret from backend or direct Stripe API
      final intentData = await _createPaymentIntent(
        amount: amount,
        currency: AuthConfig.stripeCurrency.toLowerCase(),
        donorName: donorName,
        donorEmail: donorEmail,
        message: message,
        tier: tier,
      );

      final clientSecret = intentData['clientSecret']?.toString();
      final paymentIntentId = intentData['paymentIntentId']?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          message: intentData['error']?.toString() ?? 'Failed to initialize Stripe PaymentIntent.',
        );
      }

      // 2. Initialize native Stripe Payment Sheet with resilient fallback
      try {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Allo Halal',
            style: ThemeMode.system,
            billingDetails: BillingDetails(
              name: donorName,
              email: donorEmail,
            ),
            googlePay: PaymentSheetGooglePay(
              merchantCountryCode: 'FR',
              currencyCode: AuthConfig.stripeCurrency.toUpperCase(),
              testEnv: AuthConfig.stripeMode != 'live',
            ),
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Color(0xFF635BFF),
              ),
            ),
          ),
        );
      } catch (_) {
        // Fallback without GooglePay if Google Play Services / Google Pay isn't configured
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Allo Halal',
            style: ThemeMode.system,
            billingDetails: BillingDetails(
              name: donorName,
              email: donorEmail,
            ),
            appearance: const PaymentSheetAppearance(
              colors: PaymentSheetAppearanceColors(
                primary: Color(0xFF635BFF),
              ),
            ),
          ),
        );
      }

      // 3. Present native Stripe Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Payment succeeded: record to Supabase
      _recordContributionToSupabase(
        amount: amount,
        tier: tier ?? 'COMMUNITY',
        transactionId: paymentIntentId ?? 'pi_${DateTime.now().millisecondsSinceEpoch}',
        donorName: donorName,
        donorEmail: donorEmail,
        message: message,
      );

      // 5. Send confirmation emails directly via SMTP
      ContributionEmailService.instance.sendContributionEmails(
        donorEmail: donorEmail,
        donorName: donorName,
        amount: amount,
        currency: AuthConfig.stripeCurrency.toUpperCase(),
        tier: tier ?? 'COMMUNITY',
        transactionId: paymentIntentId ?? 'pi_${DateTime.now().millisecondsSinceEpoch}',
        paymentMethod: 'Stripe',
      );

      return StripePaymentResult(
        success: true,
        paymentIntentId: paymentIntentId,
        message: 'Payment completed successfully!',
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const StripePaymentResult(
          success: false,
          isCancelled: true,
          message: 'Paiement annulé.',
        );
      }
      return StripePaymentResult(
        success: false,
        message: e.error.localizedMessage ?? 'Erreur Stripe.',
      );
    } catch (e) {
      return StripePaymentResult(
        success: false,
        message: 'Erreur: $e',
      );
    }
  }

  /// Helper to create PaymentIntent via backend API with direct Stripe fallback
  Future<Map<String, dynamic>> _createPaymentIntent({
    required double amount,
    required String currency,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    // 1. Backend attempt
    try {
      final uri = Uri.parse('${AppConfig.serverOrigin}/api/stripe/create-payment-intent');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amount': amount,
              'currency': currency,
              'donorName': donorName ?? 'Allo Halal Supporter',
              'donorEmail': donorEmail ?? '',
              'message': message ?? 'Contribution Allo Halal',
              'tier': tier ?? 'COMMUNITY',
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['clientSecret'] != null) {
          return data;
        }
      }
    } catch (_) {}

    // 2. Direct Stripe REST API fallback if secret key is present
    final secretKey = AuthConfig.stripeSecretKey.trim();
    if (secretKey.isNotEmpty && (secretKey.startsWith('sk_test_') || secretKey.startsWith('sk_live_') || secretKey.startsWith('sk_'))) {
      try {
        final endpoint = Uri.parse('https://api.stripe.com/v1/payment_intents');
        final unitAmountCents = (amount * 100).toInt().toString();

        final res = await http
            .post(
              endpoint,
              headers: {
                'Authorization': 'Bearer $secretKey',
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              body: {
                'amount': unitAmountCents,
                'currency': currency,
                'automatic_payment_methods[enabled]': 'true',
                'description': 'Contribution Allo Halal ($tier)',
                if (donorEmail != null && donorEmail.isNotEmpty) 'receipt_email': donorEmail,
                'metadata[donor_name]': donorName ?? 'Allo Halal Supporter',
                'metadata[tier]': tier ?? 'COMMUNITY',
                'metadata[message]': message ?? '',
              },
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return {
            'success': true,
            'clientSecret': data['client_secret'],
            'paymentIntentId': data['id'],
          };
        } else {
          final errData = jsonDecode(res.body) as Map<String, dynamic>;
          return {
            'success': false,
            'error': errData['error']?['message'] ?? 'Erreur Stripe API.',
          };
        }
      } catch (e) {
        return {'success': false, 'error': 'Erreur Stripe: $e'};
      }
    }

    if (secretKey.isEmpty) {
      return {
        'success': false,
        'error': 'Clé secrète Stripe non configurée. Renseignez sk_test_... dans le panneau Admin.',
      };
    }

    return {
      'success': false,
      'error': 'Clé secrète Stripe invalide (doit commencer par sk_test_ ou sk_live_).',
    };
  }

  /// Fallback checkout session URL generator
  Future<StripeSessionResult> createStripeSession({
    required double amount,
    String? donorName,
    String? donorEmail,
    String? message,
    String? tier,
  }) async {
    // 1. Try backend API endpoint
    try {
      final backendUri = Uri.parse('${AppConfig.serverOrigin}/api/stripe/create-checkout-session');
      final res = await http.post(
        backendUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'donorName': donorName ?? 'Allo Halal Supporter',
          'donorEmail': donorEmail ?? '',
          'message': message ?? 'Contribution Allo Halal',
          'tier': tier ?? 'COMMUNITY',
          'returnUrl': '${AppConfig.serverOrigin}/payment-success',
          'cancelUrl': '${AppConfig.serverOrigin}/payment-cancelled',
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['url'] != null) {
          final sId = data['sessionId']?.toString() ?? data['transactionId']?.toString();
          return StripeSessionResult(
            success: true,
            url: data['url'].toString(),
            sessionId: sId,
            message: 'Session created',
          );
        }
      }
    } catch (_) {}

    // 2. Direct Stripe REST API fallback using secret key
    final secretKey = AuthConfig.stripeSecretKey.trim();
    if (secretKey.isNotEmpty && (secretKey.startsWith('sk_test_') || secretKey.startsWith('sk_live_') || secretKey.startsWith('sk_'))) {
      try {
        final unitAmountCents = (amount * 100).toInt().toString();
        final endpoint = Uri.parse('https://api.stripe.com/v1/checkout/sessions');
        final res = await http.post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $secretKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'payment_method_types[0]': 'card',
            'mode': 'payment',
            'line_items[0][price_data][currency]': AuthConfig.stripeCurrency.toLowerCase(),
            'line_items[0][price_data][unit_amount]': unitAmountCents,
            'line_items[0][price_data][product_data][name]': 'Contribution Allo Halal (${tier ?? "COMMUNITY"})',
            'line_items[0][quantity]': '1',
            if (donorEmail != null && donorEmail.isNotEmpty) 'customer_email': donorEmail,
            'metadata[donor_name]': donorName ?? 'Allo Halal Supporter',
            'metadata[tier]': tier ?? 'COMMUNITY',
            'metadata[message]': message ?? '',
            'success_url': 'https://allohalal.fr/payment-success?session_id={CHECKOUT_SESSION_ID}',
            'cancel_url': 'https://allohalal.fr/payment-cancelled',
          },
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['url'] != null) {
            return StripeSessionResult(
              success: true,
              url: data['url'].toString(),
              sessionId: data['id']?.toString(),
              message: 'Session created successfully via direct Stripe API',
            );
          }
        }
      } catch (_) {}
    }

    return const StripeSessionResult(
      success: false,
      message: 'Failed to create checkout session.',
    );
  }

  /// Automatically records the transaction to Supabase
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
        'currency': AuthConfig.stripeCurrency.toUpperCase(),
        'tier': validTier,
        'payment_method': 'STRIPE',
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
            'provider': 'STRIPE',
            'amount': amount,
            'currency': AuthConfig.stripeCurrency.toUpperCase(),
            'donorName': donorName ?? '',
            'donorEmail': donorEmail ?? '',
            'tier': validTier,
          }),
        ).timeout(const Duration(seconds: 6));
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) debugPrint('[StripeService] Supabase log error: $e');
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
          'provider': 'STRIPE',
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
