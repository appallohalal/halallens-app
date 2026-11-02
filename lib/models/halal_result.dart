/// Represents the halal status of a single ingredient.
class IngredientResult {
  final String ingredient;
  final HalalStatus status;
  final String reason;

  const IngredientResult({
    required this.ingredient,
    required this.status,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'ingredient': ingredient,
    'status': status.name,
    'reason': reason,
  };

  factory IngredientResult.fromJson(Map<String, dynamic> json) {
    return IngredientResult(
      ingredient: json['ingredient'] as String,
      status: HalalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => HalalStatus.doubtful,
      ),
      reason: json['reason'] as String,
    );
  }
}

/// Represents the overall halal analysis result for a product.
class HalalResult {
  final HalalStatus overallStatus;
  final List<IngredientResult> ingredientResults;
  final List<String> haramIngredients;
  final List<String> doubtfulIngredients;
  final List<String> halalIngredients;

  /// Official or detected Halal certification body (e.g. AVS, Achahada, Mosquée de Paris)
  final String? certifier;

  /// True if a certifier or official certification mark was detected or validated
  final bool isCertified;

  /// True if verified directly by Allo Halal moderator / admin
  final bool verifiedOfficial;

  /// Additional notes about certification
  final String? certificationDetails;

  /// True when no official ingredient list was available and the verdict was
  /// estimated by the AI from the product identity (name, brand, category).
  final bool isEstimated;

  const HalalResult({
    required this.overallStatus,
    required this.ingredientResults,
    required this.haramIngredients,
    required this.doubtfulIngredients,
    required this.halalIngredients,
    this.certifier,
    this.isCertified = false,
    this.verifiedOfficial = false,
    this.certificationDetails,
    this.isEstimated = false,
  });

  Map<String, dynamic> toJson() => {
    'overallStatus': overallStatus.name,
    'ingredientResults': ingredientResults.map((e) => e.toJson()).toList(),
    'haramIngredients': haramIngredients,
    'doubtfulIngredients': doubtfulIngredients,
    'halalIngredients': halalIngredients,
    'certifier': certifier,
    'isCertified': isCertified,
    'verifiedOfficial': verifiedOfficial,
    'certificationDetails': certificationDetails,
    'isEstimated': isEstimated,
  };

  factory HalalResult.fromJson(Map<String, dynamic> json) {
    return HalalResult(
      overallStatus: HalalStatus.values.firstWhere(
        (e) => e.name == json['overallStatus'] || e.name == json['overall_status'],
        orElse: () => HalalStatus.doubtful,
      ),
      ingredientResults:
          (json['ingredientResults'] as List<dynamic>? ??
                  json['ingredients'] as List<dynamic>?)
              ?.map((e) => IngredientResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      haramIngredients: List<String>.from(json['haramIngredients'] ?? []),
      doubtfulIngredients: List<String>.from(json['doubtfulIngredients'] ?? []),
      halalIngredients: List<String>.from(json['halalIngredients'] ?? []),
      certifier: json['certifier']?.toString() ??
          json['certification_body']?.toString() ??
          json['certificationBody']?.toString(),
      isCertified: json['isCertified'] == true ||
          json['is_certified'] == true ||
          json['certification_detected'] == true ||
          (json['certifier'] != null && json['certifier'].toString().isNotEmpty) ||
          (json['certification_body'] != null && json['certification_body'].toString().isNotEmpty),
      verifiedOfficial: json['verifiedOfficial'] == true || json['verified_official'] == true,
      certificationDetails: json['certificationDetails']?.toString() ??
          json['certification_details']?.toString(),
      isEstimated: json['isEstimated'] == true || json['is_estimated'] == true,
    );
  }
}

/// Enum representing the halal classification status.
enum HalalStatus {
  halal,
  haram,
  doubtful;

  String get labelKey {
    switch (this) {
      case HalalStatus.halal:
        return 'result.halal_label';
      case HalalStatus.haram:
        return 'result.haram_label';
      case HalalStatus.doubtful:
        return 'result.doubtful_label';
    }
  }

  String get emoji {
    switch (this) {
      case HalalStatus.halal:
        return '✅';
      case HalalStatus.haram:
        return '❌';
      case HalalStatus.doubtful:
        return '⚠️';
    }
  }
}
