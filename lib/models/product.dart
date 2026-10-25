import 'package:easy_localization/easy_localization.dart';

/// Represents a product fetched from Open Food Facts API.
class Product {
  final String barcode;
  final String name;
  final String ingredients;
  final List<String> additives;
  final List<ParsedIngredient> parsedIngredients;
  final String? imageUrl;
  final String? brands;
  final String? quantity;
  final String? categories;

  const Product({
    required this.barcode,
    required this.name,
    required this.ingredients,
    required this.additives,
    this.parsedIngredients = const [],
    this.imageUrl,
    this.brands,
    this.quantity,
    this.categories,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};

    // Extract additives, cleaning the "en:" prefix
    final additivesTags =
        (product['additives_tags'] as List<dynamic>?)
            ?.map((e) => e.toString().replaceFirst('en:', ''))
            .toList() ??
        [];

    // Prefer English ingredients text, fallback to default
    final ingredientsTextEn = product['ingredients_text_en']?.toString() ?? '';
    final ingredientsTextDefault =
        product['ingredients_text']?.toString() ?? '';
    final ingredientsText = ingredientsTextEn.isNotEmpty
        ? ingredientsTextEn
        : ingredientsTextDefault;

    // Extract structured ingredients from parsed array (recursively)
    final parsedIngredients = <ParsedIngredient>[];
    final ingredientsList = product['ingredients'] as List<dynamic>?;
    if (ingredientsList != null) {
      _extractIngredients(ingredientsList, parsedIngredients);
    }

    return Product(
      barcode: product['code']?.toString() ?? json['code']?.toString() ?? '',
      name:
          (product['product_name_en']?.toString().isNotEmpty == true
              ? product['product_name_en'].toString()
              : null) ??
          product['product_name']?.toString() ??
          'general.unknown_product'.tr(),
      ingredients: ingredientsText,
      additives: additivesTags,
      parsedIngredients: parsedIngredients,
      imageUrl: product['image_front_url']?.toString(),
      brands: product['brands']?.toString(),
      quantity: product['quantity']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'ingredients': ingredients,
      'additives': additives,
      'parsedIngredients': parsedIngredients.map((e) => e.toJson()).toList(),
      'imageUrl': imageUrl,
      'brands': brands,
      'quantity': quantity,
      'categories': categories,
    };
  }

  factory Product.fromLocalJson(Map<String, dynamic> json) {
    return Product(
      barcode: json['barcode'] as String? ?? '',
      name: json['name'] as String? ?? 'general.unknown_product'.tr(),
      ingredients: json['ingredients'] as String? ?? '',
      additives:
          (json['additives'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parsedIngredients:
          (json['parsedIngredients'] as List<dynamic>?)
              ?.map((e) => ParsedIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: json['imageUrl'] as String?,
      brands: json['brands'] as String?,
      quantity: json['quantity'] as String?,
      categories: json['categories'] as String?,
    );
  }

  /// Recursively extracts ingredients from nested API structure.
  static void _extractIngredients(
    List<dynamic> ingredientsList,
    List<ParsedIngredient> results,
  ) {
    for (final ing in ingredientsList) {
      if (ing is Map<String, dynamic>) {
        final id = ing['id']?.toString() ?? '';
        final text = ing['text']?.toString() ?? '';
        final vegan = ing['vegan']?.toString();
        final vegetarian = ing['vegetarian']?.toString();

        if (id.isNotEmpty) {
          results.add(
            ParsedIngredient(
              id: id.replaceFirst('en:', ''),
              text: text,
              vegan: vegan,
              vegetarian: vegetarian,
            ),
          );
        }

        // Recurse into sub-ingredients
        final subIngredients = ing['ingredients'] as List<dynamic>?;
        if (subIngredients != null) {
          _extractIngredients(subIngredients, results);
        }
      }
    }
  }
}

/// A structured ingredient from the API with taxonomy ID and metadata.
class ParsedIngredient {
  final String id; // e.g. "sugar", "palm-oil", "gelatin"
  final String text; // Display name, e.g. "Sucre", "Sugar"
  final String? vegan; // "yes", "no", "maybe", or null
  final String? vegetarian; // "yes", "no", "maybe", or null

  const ParsedIngredient({
    required this.id,
    required this.text,
    this.vegan,
    this.vegetarian,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'text': text, 'vegan': vegan, 'vegetarian': vegetarian};
  }

  factory ParsedIngredient.fromJson(Map<String, dynamic> json) {
    return ParsedIngredient(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      vegan: json['vegan'] as String?,
      vegetarian: json['vegetarian'] as String?,
    );
  }
}
