import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class ProductCommunityService {
  ProductCommunityService._();

  static const int maxImageBytes = 10 * 1024 * 1024; // 10MB

  static Map<String, String> get _sbHeaders => {
        'apikey': AppConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

  static Future<String?> _getFcmTokenSafe() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Validates file type & size and uploads an image to Supabase Storage `product-media`.
  static Future<String> uploadUnknownProductPhoto({
    required File file,
    required String barcode,
    required String slot,
  }) async {
    final size = await file.length();
    if (size > maxImageBytes) {
      throw Exception('Image trop volumineuse (max 10 Mo).');
    }

    final lower = file.path.toLowerCase();
    String contentType = 'image/jpeg';
    String ext = 'jpg';
    if (lower.endsWith('.png')) {
      contentType = 'image/png';
      ext = 'png';
    } else if (lower.endsWith('.webp')) {
      contentType = 'image/webp';
      ext = 'webp';
    } else if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
      throw Exception('Format non supporté. Utilisez JPEG, PNG ou WebP.');
    }

    final safeBarcode = barcode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final objectPath =
        'unknown-products/$safeBarcode/${slot}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final bytes = await file.readAsBytes();
    final uploadUri = Uri.parse(
      '${AppConfig.supabaseUrl}/storage/v1/object/product-media/$objectPath',
    );

    final res = await http
        .post(
          uploadUri,
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            'Content-Type': contentType,
            'x-upsert': 'true',
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Échec de l\'envoi de la photo (${res.statusCode}).');
    }

    return '${AppConfig.supabaseUrl}/storage/v1/object/public/product-media/$objectPath';
  }

  /// Records a scan of an unknown barcode in `unknown_products` (fire-and-forget safe).
  static Future<void> logUnknownBarcodeScan(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return;

    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/unknown-products'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'barcode': clean, 'scanOnly': true}),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode >= 200 && res.statusCode < 300) return;
    } catch (_) {}

    // Direct Supabase REST fallback
    try {
      final getUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/unknown_products?barcode=eq.${Uri.encodeComponent(clean)}&select=id,scans_count&limit=1',
      );
      final getRes = await http.get(getUri, headers: _sbHeaders).timeout(const Duration(seconds: 4));
      if (getRes.statusCode == 200) {
        final rows = json.decode(getRes.body) as List<dynamic>;
        if (rows.isNotEmpty) {
          final id = rows.first['id'];
          final count = (rows.first['scans_count'] as int? ?? 1) + 1;
          await http.patch(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/unknown_products?id=eq.$id'),
            headers: _sbHeaders,
            body: json.encode({
              'scans_count': count,
              'last_scanned_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
          );
          return;
        }
      }
      await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/unknown_products'),
        headers: _sbHeaders,
        body: json.encode({'barcode': clean, 'status': 'nouveau', 'scans_count': 1}),
      );
    } catch (_) {}
  }

  /// Submits photos and optional notification preference for an unknown product.
  static Future<void> submitUnknownProduct({
    required String barcode,
    File? frontPhoto,
    File? ingredientsPhoto,
    File? certifierPhoto,
    required bool notifyWhenReady,
  }) async {
    final clean = barcode.trim();
    if (clean.isEmpty) throw Exception('Code-barres manquant.');

    String? frontUrl;
    String? ingredientsUrl;
    String? certifierUrl;

    if (frontPhoto != null) {
      frontUrl = await uploadUnknownProductPhoto(
        file: frontPhoto,
        barcode: clean,
        slot: 'front',
      );
    }
    if (ingredientsPhoto != null) {
      ingredientsUrl = await uploadUnknownProductPhoto(
        file: ingredientsPhoto,
        barcode: clean,
        slot: 'ingredients',
      );
    }
    if (certifierPhoto != null) {
      certifierUrl = await uploadUnknownProductPhoto(
        file: certifierPhoto,
        barcode: clean,
        slot: 'certifier',
      );
    }

    final user = AuthService.instance.currentUser;
    final deviceId = AuthService.instance.deviceId;
    final fcmToken = notifyWhenReady ? await _getFcmTokenSafe() : null;

    // 1. Try Admin API first (handles duplicate notification prevention & upsert atomically)
    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/unknown-products'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'barcode': clean,
              'userId': user?.id,
              'userEmail': user?.email,
              'deviceId': deviceId,
              'fcmToken': fcmToken,
              'notifyWhenReady': notifyWhenReady,
              'frontImageUrl': frontUrl,
              'ingredientsImageUrl': ingredientsUrl,
              'certifierImageUrl': certifierUrl,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }
    } catch (_) {}

    // 2. Direct Supabase REST fallback
    String? unknownProductId;
    final existingRes = await http
        .get(
          Uri.parse(
            '${AppConfig.supabaseUrl}/rest/v1/unknown_products?barcode=eq.${Uri.encodeComponent(clean)}&select=id,submissions_count&limit=1',
          ),
          headers: _sbHeaders,
        )
        .timeout(const Duration(seconds: 8));

    if (existingRes.statusCode == 200) {
      final rows = json.decode(existingRes.body) as List<dynamic>;
      if (rows.isNotEmpty) {
        unknownProductId = rows.first['id']?.toString();
        final subCount = (rows.first['submissions_count'] as int? ?? 0) + 1;
        await http.patch(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/unknown_products?id=eq.$unknownProductId'),
          headers: _sbHeaders,
          body: json.encode({
            'submissions_count': subCount,
            'front_image_url': ?frontUrl,
            'ingredients_image_url': ?ingredientsUrl,
            'certifier_image_url': ?certifierUrl,
            'last_scanned_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      }
    }

    if (unknownProductId == null) {
      final createRes = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/unknown_products'),
            headers: {..._sbHeaders, 'Prefer': 'return=representation'},
            body: json.encode({
              'barcode': clean,
              'status': 'nouveau',
              'scans_count': 1,
              'submissions_count': 1,
              'front_image_url': frontUrl,
              'ingredients_image_url': ingredientsUrl,
              'certifier_image_url': certifierUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (createRes.statusCode >= 200 && createRes.statusCode < 300) {
        final created = json.decode(createRes.body) as List<dynamic>;
        if (created.isNotEmpty) {
          unknownProductId = created.first['id']?.toString();
        }
      }
    }

    if (unknownProductId == null) {
      throw Exception('Impossible d\'enregistrer la soumission.');
    }

    await http
        .post(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/unknown_product_submissions'),
          headers: _sbHeaders,
          body: json.encode({
            'unknown_product_id': unknownProductId,
            'barcode': clean,
            'user_id': user?.id,
            'user_email': user?.email,
            'device_id': deviceId,
            'fcm_token': fcmToken,
            'notify_when_ready': notifyWhenReady,
            'front_image_url': frontUrl,
            'ingredients_image_url': ingredientsUrl,
            'certifier_image_url': certifierUrl,
          }),
        )
        .timeout(const Duration(seconds: 8));
  }

  /// Submits a user error report for an existing product.
  static Future<void> submitProductErrorReport({
    required String barcode,
    String? productId,
    String? productName,
    required String reportType,
    required String message,
  }) async {
    final user = AuthService.instance.currentUser;
    final deviceId = AuthService.instance.deviceId;

    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/error-reports'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'barcode': barcode,
              'productId': productId,
              'productName': productName,
              'reportType': reportType,
              'message': message,
              'userId': user?.id,
              'userEmail': user?.email,
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) return;
    } catch (_) {}

    final sbRes = await http
        .post(
          Uri.parse('${AppConfig.supabaseUrl}/rest/v1/product_error_reports'),
          headers: _sbHeaders,
          body: json.encode({
            'barcode': barcode,
            'product_id': productId,
            'product_name': productName,
            'report_type': reportType,
            'message': message,
            'user_id': user?.id,
            'user_email': user?.email,
            'device_id': deviceId,
            'status': 'nouveau',
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (sbRes.statusCode < 200 || sbRes.statusCode >= 300) {
      throw Exception('Échec de l\'envoi du signalement.');
    }
  }
}
