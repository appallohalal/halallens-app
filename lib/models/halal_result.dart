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

  const HalalResult({
    required this.overallStatus,
    required this.ingredientResults,
    required this.haramIngredients,
    required this.doubtfulIngredients,
    required this.halalIngredients,
  });

  Map<String, dynamic> toJson() => {
    'overallStatus': overallStatus.name,
    'ingredientResults': ingredientResults.map((e) => e.toJson()).toList(),
    'haramIngredients': haramIngredients,
    'doubtfulIngredients': doubtfulIngredients,
    'halalIngredients': halalIngredients,
  };

  factory HalalResult.fromJson(Map<String, dynamic> json) {
    return HalalResult(
      overallStatus: HalalStatus.values.firstWhere(
        (e) => e.name == json['overallStatus'],
        orElse: () => HalalStatus.doubtful,
      ),
      ingredientResults:
          (json['ingredientResults'] as List<dynamic>?)
              ?.map((e) => IngredientResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      haramIngredients: List<String>.from(json['haramIngredients'] ?? []),
      doubtfulIngredients: List<String>.from(json['doubtfulIngredients'] ?? []),
      halalIngredients: List<String>.from(json['halalIngredients'] ?? []),
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
