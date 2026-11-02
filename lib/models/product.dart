import 'package:easy_localization/easy_localization.dart';
import '../utils/halal_certifier_helper.dart';

/// Represents a product fetched from Open Food Facts API or Allo Halal Supabase.
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
  final String? manualStatus;
  final String? moderatorNote;
  final List<String> labels;
  final String? certifier;
  final bool isCertified;
  final bool verifiedOfficial;
  final String? certificationDetails;

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
    this.manualStatus,
    this.moderatorNote,
    this.labels = const [],
    this.certifier,
    this.isCertified = false,
    this.verifiedOfficial = false,
    this.certificationDetails,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};

    // Extract additives, cleaning language prefixes like "en:", "fr:"
    final additivesTags =
        (product['additives_tags'] as List<dynamic>?)
            ?.map((e) => e.toString().replaceAll(RegExp(r'^[a-z]{2}:'), ''))
            .toList() ??
        [];

    // Extract labels & certifications (e.g. en:halal, fr:halal)
    final labelsTags =
        (product['labels_tags'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase().trim())
            .toList() ??
        [];
    final rawLabels = product['labels']?.toString().toLowerCase().trim();
    if (rawLabels != null && rawLabels.isNotEmpty) {
      for (final part in rawLabels.split(',')) {
        final p = part.trim();
        if (p.isNotEmpty && !labelsTags.contains(p)) {
          labelsTags.add(p);
        }
      }
    }

    // Extract structured ingredients from parsed array (recursively)
    final parsedIngredients = <ParsedIngredient>[];
    final ingredientsList = product['ingredients'] as List<dynamic>?;
    if (ingredientsList != null) {
      _extractIngredients(ingredientsList, parsedIngredients);
    }

    // Multi-lingual ingredients text resolution (preferring French for EU market, then default, then English, etc.)
    final ingFr = product['ingredients_text_fr']?.toString().trim();
    final ingDef = product['ingredients_text']?.toString().trim();
    final ingEn = product['ingredients_text_en']?.toString().trim();
    final ingDe = product['ingredients_text_de']?.toString().trim();
    final ingEs = product['ingredients_text_es']?.toString().trim();
    final ingIt = product['ingredients_text_it']?.toString().trim();

    String resolvedIngredients = '';
    if (ingFr != null && ingFr.isNotEmpty) {
      resolvedIngredients = ingFr;
    } else if (ingDef != null && ingDef.isNotEmpty) {
      resolvedIngredients = ingDef;
    } else if (ingEn != null && ingEn.isNotEmpty) {
      resolvedIngredients = ingEn;
    } else if (ingDe != null && ingDe.isNotEmpty) {
      resolvedIngredients = ingDe;
    } else if (ingEs != null && ingEs.isNotEmpty) {
      resolvedIngredients = ingEs;
    } else if (ingIt != null && ingIt.isNotEmpty) {
      resolvedIngredients = ingIt;
    } else if (parsedIngredients.isNotEmpty) {
      // Fallback: reconstruct readable ingredients list from parsed taxonomy
      resolvedIngredients = parsedIngredients
          .map((p) => p.text.isNotEmpty ? p.text : p.id)
          .where((s) => s.isNotEmpty)
          .join(', ');
    }

    // Multi-lingual name resolution
    final nameFr = product['product_name_fr']?.toString().trim();
    final nameDef = product['product_name']?.toString().trim();
    final nameGenericFr = product['generic_name_fr']?.toString().trim();
    final nameEn = product['product_name_en']?.toString().trim();
    final nameGeneric = product['generic_name']?.toString().trim();

    String resolvedName = '';
    if (nameFr != null && nameFr.isNotEmpty) {
      resolvedName = nameFr;
    } else if (nameDef != null && nameDef.isNotEmpty) {
      resolvedName = nameDef;
    } else if (nameGenericFr != null && nameGenericFr.isNotEmpty) {
      resolvedName = nameGenericFr;
    } else if (nameEn != null && nameEn.isNotEmpty) {
      resolvedName = nameEn;
    } else if (nameGeneric != null && nameGeneric.isNotEmpty) {
      resolvedName = nameGeneric;
    } else {
      resolvedName = 'general.unknown_product'.tr();
    }

    final imageUrl = product['image_front_url']?.toString() ??
        product['image_url']?.toString();

    // Certification detection / resolution
    final explicitCert = json['certifier']?.toString() ??
        product['certifier']?.toString();
    final explicitVerifiedOfficial = json['verifiedOfficial'] == true ||
        json['verified_official'] == true ||
        product['verified_official'] == true;
    final explicitIsCertified = json['isCertified'] == true ||
        json['is_certified'] == true ||
        product['is_certified'] == true;
    final certDetails = json['certificationDetails']?.toString() ??
        product['certification_details']?.toString();

    final detectedCert = explicitCert != null && explicitCert.trim().isNotEmpty
        ? explicitCert.trim()
        : HalalCertifierHelper.detectCertifier(
            labels: labelsTags,
            name: resolvedName,
            brand: product['brands']?.toString(),
            ingredients: resolvedIngredients,
          );

    final isCertFinal = explicitIsCertified || (detectedCert != null && detectedCert.isNotEmpty);

    return Product(
      barcode: product['code']?.toString() ?? json['code']?.toString() ?? '',
      name: resolvedName,
      ingredients: resolvedIngredients,
      additives: additivesTags,
      parsedIngredients: parsedIngredients,
      imageUrl: imageUrl,
      brands: product['brands']?.toString(),
      quantity: product['quantity']?.toString(),
      categories: product['categories']?.toString(),
      manualStatus: json['manual_status']?.toString() ?? json['status']?.toString(),
      moderatorNote: json['moderator_note']?.toString() ?? json['moderatorNote']?.toString(),
      labels: labelsTags,
      certifier: detectedCert,
      isCertified: isCertFinal,
      verifiedOfficial: explicitVerifiedOfficial,
      certificationDetails: certDetails,
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
      'manualStatus': manualStatus,
      'moderatorNote': moderatorNote,
      'labels': labels,
      'certifier': certifier,
      'isCertified': isCertified,
      'verifiedOfficial': verifiedOfficial,
      'certificationDetails': certificationDetails,
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
      manualStatus: json['manualStatus'] as String?,
      moderatorNote: json['moderatorNote'] as String?,
      labels:
          (json['labels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      certifier: json['certifier'] as String?,
      isCertified: json['isCertified'] == true,
      verifiedOfficial: json['verifiedOfficial'] == true,
      certificationDetails: json['certificationDetails'] as String?,
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
