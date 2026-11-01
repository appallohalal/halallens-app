import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/app_config.dart';
import 'package:easy_localization/easy_localization.dart';

/// Service responsible for fetching product data from Supabase `products` catalog first,
/// and falling back to the Open Food Facts API if not found in our database.
class ApiService {
  static const Duration _timeout = Duration(seconds: 12);

  static const String _offFields =
      'code,product_name,product_name_fr,product_name_en,product_name_de,product_name_es,product_name_it,'
      'generic_name,generic_name_fr,generic_name_en,'
      'ingredients_text,ingredients_text_fr,ingredients_text_en,ingredients_text_de,ingredients_text_es,ingredients_text_it,'
      'ingredients,ingredients_analysis_tags,additives_tags,labels_tags,labels,'
      'image_front_url,image_url,brands,quantity,categories,categories_tags';

  static const Map<String, String> _headers = {
    'User-Agent': 'AlloHalal - Flutter Mobile App - Android/iOS - https://allohalal.fr',
    'Accept': 'application/json',
  };

  /// Generates candidate barcodes to handle EAN-13 vs UPC-A format differences.
  List<String> _getCandidateBarcodes(String barcode) {
    final clean = barcode.trim().replaceAll(RegExp(r'\s+'), '');
    final candidates = <String>[clean];

    // If 12-digit UPC-A, OFF often indexes with a leading 0 (EAN-13)
    if (clean.length == 12 && RegExp(r'^\d{12}$').hasMatch(clean)) {
      candidates.add('0$clean');
    }

    // If 13-digit EAN-13 starting with 0, check 12-digit UPC-A
    if (clean.length == 13 && clean.startsWith('0')) {
      candidates.add(clean.substring(1));
    }

    // If 14-digit GTIN starting with 00, check 13-digit and 12-digit
    if (clean.length == 14 && clean.startsWith('0')) {
      final stripped = clean.replaceFirst(RegExp(r'^0+'), '');
      if (stripped.isNotEmpty && !candidates.contains(stripped)) {
        candidates.add(stripped);
      }
    }

    return candidates;
  }

  /// Fetches product details for the given [barcode].
  /// 1. Checks Supabase `products` table directly (always online, instant).
  /// 2. Checks Admin backend `/scan` endpoint.
  /// 3. Falls back to Open Food Facts API (multi-endpoint & candidates).
  Future<Product> fetchProduct(String barcode) async {
    final candidates = _getCandidateBarcodes(barcode);
    final primaryBarcode = candidates.first;

    // 1. Check Supabase `products` table directly first using candidates
    for (final candidate in candidates) {
      try {
        final sbUri = Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/products?barcode=eq.${Uri.encodeComponent(candidate)}&select=*&limit=1',
        );
        final sbRes = await http
            .get(
              sbUri,
              headers: {
                'apikey': AppConfig.supabaseAnonKey,
                'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              },
            )
            .timeout(const Duration(seconds: 4));

        if (sbRes.statusCode == 200) {
          final rows = json.decode(sbRes.body) as List<dynamic>;
          if (rows.isNotEmpty) {
            final p = rows.first as Map<String, dynamic>;
            final additives = (p['detected_additives'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final status = (p['manual_status'] ?? p['ai_status'])?.toString();
            return Product(
              barcode: p['barcode']?.toString() ?? candidate,
              name: p['name']?.toString() ?? 'general.unknown_product'.tr(),
              ingredients: p['ingredients_raw']?.toString() ?? '',
              additives: additives,
              brands: p['brand']?.toString(),
              imageUrl: p['image_url']?.toString(),
              manualStatus: status,
              moderatorNote: p['moderator_note']?.toString(),
            );
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: Check Admin backend `/scan` endpoint
    try {
      final backendUri = Uri.parse('${AppConfig.backendBaseUrl}/scan');
      final backendRes = await http
          .post(
            backendUri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'barcode': primaryBarcode}),
          )
          .timeout(const Duration(seconds: 4));

      if (backendRes.statusCode == 200) {
        final bData = json.decode(backendRes.body) as Map<String, dynamic>;
        if (bData['found'] == true && bData['product'] != null) {
          final p = bData['product'] as Map<String, dynamic>;
          final additives = (p['detectedAdditives'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          return Product(
            barcode: p['barcode']?.toString() ?? primaryBarcode,
            name: p['name']?.toString() ?? 'general.unknown_product'.tr(),
            ingredients: p['ingredientsRaw']?.toString() ?? '',
            additives: additives,
            brands: p['brand']?.toString(),
            imageUrl: p['imageUrl']?.toString(),
            manualStatus: p['status']?.toString(),
            moderatorNote: p['moderatorNote']?.toString(),
          );
        }
      }
    } catch (_) {}

    // 3. Fallback: Query Open Food Facts API with mirrors & candidates
    for (final candidate in candidates) {
      final urlsToTry = [
        'https://world.openfoodfacts.org/api/v2/product/$candidate?fields=$_offFields',
        'https://fr.openfoodfacts.org/api/v2/product/$candidate?fields=$_offFields',
        'https://world.openfoodfacts.org/api/v0/product/$candidate.json',
      ];

      for (final urlStr in urlsToTry) {
        try {
          final uri = Uri.parse(urlStr);
          final response = await http
              .get(uri, headers: _headers)
              .timeout(_timeout);

          if (response.statusCode == 200) {
            final data = json.decode(response.body) as Map<String, dynamic>;

            if (data['status'] == 1 && data['product'] != null) {
              return Product.fromJson(data);
            }
          }
        } catch (_) {
          // Continue to next mirror or candidate
        }
      }
    }

    throw ProductNotFoundException(
      "errors.product_not_found".tr(),
      barcode: primaryBarcode,
    );
  }
}

/// Exception thrown when a product is not found in the API.
class ProductNotFoundException implements Exception {
  final String message;
  final String? barcode;
  const ProductNotFoundException(this.message, {this.barcode});

  @override
  String toString() => message;
}

/// Exception thrown for general API errors.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
