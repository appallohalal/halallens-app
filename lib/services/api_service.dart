import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/app_config.dart';
import 'package:easy_localization/easy_localization.dart';

/// Service responsible for fetching product data from the Open Food Facts API
/// and checking HalalLens Admin backend for verified records/overrides.
class ApiService {
  // Use API v2 for better structured data
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v2/product';

  static const Duration _timeout = Duration(seconds: 15);

  /// Fetches product details for the given [barcode].
  /// Checks HalalLens Backend first for moderator-verified products.
  Future<Product> fetchProduct(String barcode) async {
    // 1. Try checking HalalLens Admin backend cache & moderator overrides first
    try {
      final backendUri = Uri.parse('${AppConfig.backendBaseUrl}/scan');
      final backendRes = await http
          .post(
            backendUri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'barcode': barcode}),
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
            barcode: p['barcode']?.toString() ?? barcode,
            name: p['name']?.toString() ?? 'general.unknown_product'.tr(),
            ingredients: p['ingredientsRaw']?.toString() ?? '',
            additives: additives,
            brands: p['brand']?.toString(),
            imageUrl: p['imageUrl']?.toString(),
          );
        }
      }
    } catch (_) {
      // Fallback seamlessly to Open Food Facts
    }

    // 2. Request from Open Food Facts API
    final uri = Uri.parse(
      '$_baseUrl/$barcode?fields='
      'code,product_name,product_name_en,'
      'ingredients_text_en,ingredients_text,'
      'ingredients,'
      'ingredients_analysis_tags,'
      'additives_tags,'
      'image_front_url,'
      'brands,quantity,categories',
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'HalalLens - Flutter App - v2.0'})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'failure' ||
            data['status'] == 0 ||
            data['product'] == null) {
          throw ProductNotFoundException("errors.product_not_found".tr());
        }

        return Product.fromJson(data);
      } else {
        throw ApiException("errors.server_error".tr());
      }
    } on ProductNotFoundException {
      rethrow;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException("errors.network_error".tr());
    }
  }
}

/// Exception thrown when a product is not found in the API.
class ProductNotFoundException implements Exception {
  final String message;
  const ProductNotFoundException(this.message);

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
