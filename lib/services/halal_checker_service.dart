import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/halal_result.dart';
import '../models/product.dart';

/// Service responsible for checking ingredients against the halal database.
///
/// Uses Open Food Facts taxonomy IDs for accurate matching instead of
/// fuzzy string matching which causes false positives.
class HalalCheckerService {
  // Database keyed by taxonomy ID (e.g., "gelatin", "palm-oil", "sugar")
  Map<String, Map<String, String>> _database = {};
  bool _isLoaded = false;

  /// Known haram taxonomy IDs from Open Food Facts ingredient hierarchy.
  /// These are checked via exact ID matching — no false positives.
  static const Set<String> _haramIds = {
    'gelatin', 'gelatine',
    'pork', 'pork-meat', 'pork-fat', 'pork-gelatin',
    'lard',
    'bacon',
    'ham',
    'pepsin',
    'carmine', 'carminic-acid',
    'cochineal',
    'alcohol', 'ethanol', 'ethyl-alcohol',
    'wine', 'red-wine', 'white-wine', 'wine-vinegar',
    'rum', 'brandy', 'whiskey', 'vodka', 'beer',
    'tallow', 'beef-tallow',
    'animal-fat',
    'e120', // Cochineal
    'e441', // Gelatin
    'e542', // Bone phosphate
    'e904', // Shellac
    'pig', 'pig-fat', 'pig-skin',
    'blood', 'blood-sausage',
    'l-cysteine', // Often from human hair or duck feathers
  };

  /// Known doubtful taxonomy IDs.
  static const Set<String> _doubtfulIds = {
    'e471',
    'e472',
    'e472a',
    'e472b',
    'e472c',
    'e472e',
    'e473',
    'e474',
    'e475',
    'e476',
    'e481',
    'e482',
    'e491',
    'e492',
    'e493',
    'e494',
    'e495',
    'e570',
    'e572',
    'e631',
    'e635',
    'glycerin',
    'glycerol',
    'glycerine',
    'mono-and-diglycerides-of-fatty-acids',
    'whey',
    'whey-powder',
    'whey-protein',
    'rennet',
    'cheese',
    'natural-flavoring',
    'natural-flavour',
    'natural-flavor',
    'flavouring',
    'emulsifier',
    'chicken',
    'chicken-meat',
    'chicken-fat',
    'beef',
    'beef-meat',
    'beef-fat',
    'lamb',
    'lamb-meat',
    'oil-and-fat',
    'animal-protein',
    'stearic-acid',
    'magnesium-stearate',
  };

  /// Known halal taxonomy IDs (common ones).
  static const Set<String> _halalIds = {
    'sugar', 'added-sugar', 'cane-sugar', 'brown-sugar', 'disaccharide',
    'salt', 'sea-salt', 'sodium', 'sodium-chloride',
    'water',
    'flour', 'wheat-flour', 'wheat', 'rice-flour', 'corn-flour',
    'rice', 'corn', 'oat', 'barley', 'rye',
    'milk', 'skimmed-milk', 'skimmed-milk-powder', 'milk-powder',
    'whole-milk', 'whole-milk-powder', 'condensed-milk',
    'semi-skimmed-milk', 'fat-reduced-milk',
    'butter', 'butterfat', 'butter-oil', 'buttermilk',
    'cream', 'sour-cream', 'cream-cheese',
    'yogurt', 'yoghurt',
    'egg', 'eggs', 'egg-white', 'egg-yolk', 'whole-egg',
    'honey',
    'cocoa', 'cocoa-butter', 'cocoa-powder', 'cocoa-mass',
    'fat-reduced-cocoa', 'cocoa-paste',
    'chocolate', 'dark-chocolate', 'milk-chocolate',
    'vanilla', 'vanillin', 'vanilla-extract', 'vanilla-sugar',
    'palm-oil', 'palm-fat', 'palm-oil-and-fat', 'palm-kernel-oil',
    'olive-oil', 'extra-virgin-olive-oil',
    'sunflower-oil', 'sunflower-seed-oil',
    'soybean-oil', 'soy-oil',
    'rapeseed-oil', 'canola-oil',
    'coconut-oil', 'coconut-fat',
    'corn-oil', 'cottonseed-oil', 'peanut-oil', 'sesame-oil',
    'vegetable-oil', 'vegetable-fat', 'vegetable-oil-and-fat',
    'hazelnut', 'hazelnuts', 'almond', 'almonds',
    'peanut', 'peanuts', 'walnut', 'walnuts',
    'cashew', 'cashew-nut', 'pistachio', 'macadamia',
    'nut', 'tree-nut',
    'soy', 'soya', 'soya-lecithin', 'soy-sauce',
    'lecithin', 'sunflower-lecithin',
    'tofu', 'soy-protein',
    'citric-acid', 'ascorbic-acid', 'lactic-acid', 'malic-acid',
    'tartaric-acid', 'acetic-acid', 'phosphoric-acid',
    'baking-powder', 'baking-soda', 'sodium-bicarbonate',
    'yeast', 'bakers-yeast',
    'pectin', 'agar-agar', 'carrageenan',
    'starch', 'corn-starch', 'potato-starch', 'modified-starch',
    'wheat-starch', 'rice-starch', 'tapioca-starch',
    'glucose', 'fructose', 'glucose-fructose-syrup', 'glucose-syrup',
    'fructose-syrup', 'corn-syrup', 'maple-syrup', 'agave-syrup',
    'potato', 'tomato', 'onion', 'garlic', 'ginger', 'turmeric',
    'pepper', 'black-pepper', 'chili-pepper', 'paprika',
    'cinnamon', 'cardamom', 'cumin', 'coriander', 'nutmeg',
    'spice', 'spices', 'herb', 'herbs',
    'lemon', 'lime', 'orange', 'apple', 'banana', 'strawberry',
    'mango', 'pineapple', 'grape', 'berry', 'blueberry', 'raspberry',
    'fruit', 'fruit-juice', 'fruit-puree',
    'vinegar', 'apple-cider-vinegar',
    'mustard', 'ketchup', 'mayonnaise',
    'fish', 'salmon', 'tuna', 'cod', 'sardine', 'shrimp', 'prawn',
    'coffee', 'tea', 'green-tea', 'caffeine', 'caffeine-flavour',
    'carbonated-water', 'sparkling-water', 'mineral-water',
    'colour', 'coloring', 'acid',
    'raising-agent', 'acidity-regulator', 'stabiliser', 'thickener',
    'antioxidant', 'preservative', 'humectant', 'glazing-agent',
    'fat-reduced-cocoa-powder', 'low-fat-cocoa-powder',
    'plant', 'dairy',
    // Common E-numbers that are halal
    'e100', 'e101', 'e102', 'e104', 'e110',
    'e150a', 'e150b', 'e150c', 'e150d',
    'e160a', 'e160b', 'e160c',
    'e162', 'e170', 'e171',
    'e200', 'e202', 'e210', 'e211',
    'e270', 'e290',
    'e300', 'e301', 'e302', 'e306', 'e307', 'e308',
    'e322', 'e322i', 'e322ii',
    'e330', 'e331', 'e332', 'e333', 'e334', 'e335', 'e336', 'e337',
    'e338', 'e339', 'e340', 'e341',
    'e400', 'e401', 'e406', 'e407', 'e410', 'e412', 'e414', 'e415',
    'e420', 'e421', 'e440',
    'e500', 'e501', 'e503', 'e504',
    'e508', 'e509', 'e511', 'e524',
    'e621', // MSG
    'e950', 'e951', 'e952', 'e954', 'e955', 'e960', 'e961', 'e965',
  };

  /// Loads the halal ingredient database from assets (supplementary).
  Future<void> loadDatabase() async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/halal_database.json',
      );
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final ingredients = data['ingredients'] as Map<String, dynamic>;

      _database = ingredients.map((key, value) {
        final entry = value as Map<String, dynamic>;
        return MapEntry(key.toLowerCase().trim(), {
          'status': entry['status']?.toString() ?? 'unknown',
          'reason': entry['reason']?.toString() ?? 'No information available.',
        });
      });

      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load halal database: $e');
    }
  }

  /// Checks ingredients using structured API data for accurate results.
  ///
  /// Priority: taxonomy ID match > JSON database match > vegan/vegetarian hint
  HalalResult checkIngredients(
    String ingredientsText,
    List<String> additives, {
    List<ParsedIngredient> parsedIngredients = const [],
  }) {
    final ingredientResults = <IngredientResult>[];
    final haramList = <String>[];
    final doubtfulList = <String>[];
    final halalList = <String>[];
    final checked = <String>{};

    // 1. Check structured ingredients from API (most accurate)
    for (final ing in parsedIngredients) {
      final normalizedId = ing.id.toLowerCase().trim();
      if (normalizedId.isEmpty || checked.contains(normalizedId)) continue;
      checked.add(normalizedId);

      final displayName = ing.text.isNotEmpty ? ing.text : normalizedId;
      final result = _checkIngredientById(normalizedId, displayName, ing);

      ingredientResults.add(result);

      switch (result.status) {
        case HalalStatus.haram:
          haramList.add(displayName);
          break;
        case HalalStatus.doubtful:
          doubtfulList.add(displayName);
          break;
        case HalalStatus.halal:
          halalList.add(displayName);
      }
    }

    // 2. Check additives by exact ID match
    for (final additive in additives) {
      final normalized = additive.toLowerCase().trim();
      if (normalized.isEmpty || checked.contains(normalized)) continue;
      checked.add(normalized);

      final result = _checkAdditiveById(normalized);
      ingredientResults.add(result);

      switch (result.status) {
        case HalalStatus.haram:
          haramList.add(normalized);
          break;
        case HalalStatus.doubtful:
          doubtfulList.add(normalized);
          break;
        case HalalStatus.halal:
          halalList.add(normalized);
      }
    }

    // If no structured data, fall back to text parsing
    if (parsedIngredients.isEmpty && ingredientsText.isNotEmpty) {
      final parsed = _parseIngredients(ingredientsText);
      for (final item in parsed) {
        if (item.isEmpty || checked.contains(item)) continue;
        checked.add(item);

        final result = _checkByTextFallback(item);
        ingredientResults.add(result);

        switch (result.status) {
          case HalalStatus.haram:
            haramList.add(item);
            break;
          case HalalStatus.doubtful:
            doubtfulList.add(item);
            break;
          case HalalStatus.halal:
            halalList.add(item);
        }
      }
    }

    // Determine overall status
    HalalStatus overall;
    if (haramList.isNotEmpty) {
      overall = HalalStatus.haram;
    } else if (doubtfulList.isNotEmpty) {
      overall = HalalStatus.doubtful;
    } else if (halalList.isNotEmpty) {
      overall = HalalStatus.halal;
    } else {
      // If nothing was parsed or all were unknown (now doubtful)
      overall = HalalStatus.doubtful;
    }

    return HalalResult(
      overallStatus: overall,
      ingredientResults: ingredientResults,
      haramIngredients: haramList,
      doubtfulIngredients: doubtfulList,
      halalIngredients: halalList,
    );
  }

  /// Check an ingredient by its taxonomy ID (most accurate method).
  IngredientResult _checkIngredientById(
    String id,
    String displayName,
    ParsedIngredient ing,
  ) {
    // 1. Check against hardcoded taxonomy ID sets (exact match)
    if (_haramIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.haram,
        reason: dbEntry?['reason'] ?? _getHaramReason(id),
      );
    }

    if (_doubtfulIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.doubtful,
        reason: dbEntry?['reason'] ?? _getDoubtfulReason(id),
      );
    }

    if (_halalIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.halal,
        reason: dbEntry?['reason'] ?? 'This ingredient is halal.',
      );
    }

    // 2. Check JSON database with normalized ID (hyphen → space)
    final idWithSpaces = id.replaceAll('-', ' ');
    if (_database.containsKey(idWithSpaces)) {
      final entry = _database[idWithSpaces]!;
      return IngredientResult(
        ingredient: displayName,
        status: _parseStatus(entry['status']!),
        reason: entry['reason']!,
      );
    }
    if (_database.containsKey(id)) {
      final entry = _database[id]!;
      return IngredientResult(
        ingredient: displayName,
        status: _parseStatus(entry['status']!),
        reason: entry['reason']!,
      );
    }

    // 3. Use vegan/vegetarian metadata from API as hint
    if (ing.vegan == 'no') {
      // Contains animal products — need to verify halal status
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.doubtful,
        reason:
            'This ingredient contains animal-derived components. '
            'Halal source verification is needed.',
      );
    }

    if (ing.vegan == 'yes') {
      // Fully plant-based — generally halal
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.halal,
        reason: 'This ingredient is plant-based and halal.',
      );
    }

    if (ing.vegetarian == 'maybe' || ing.vegan == 'maybe') {
      return IngredientResult(
        ingredient: displayName,
        status: HalalStatus.doubtful,
        reason:
            'This ingredient may be animal or plant-derived. '
            'Source verification needed.',
      );
    }

    // 4. Doubtful (Unknown)
    return IngredientResult(
      ingredient: displayName,
      status: HalalStatus.doubtful,
      reason: 'This ingredient is not in our database.',
    );
  }

  /// Check an additive by exact ID match.
  IngredientResult _checkAdditiveById(String id) {
    if (_haramIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: id.toUpperCase(),
        status: HalalStatus.haram,
        reason: dbEntry?['reason'] ?? 'This additive is considered haram.',
      );
    }
    if (_doubtfulIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: id.toUpperCase(),
        status: HalalStatus.doubtful,
        reason:
            dbEntry?['reason'] ??
            'This additive may be from animal or plant sources.',
      );
    }
    if (_halalIds.contains(id)) {
      final dbEntry = _database[id];
      return IngredientResult(
        ingredient: id.toUpperCase(),
        status: HalalStatus.halal,
        reason: dbEntry?['reason'] ?? 'This additive is halal.',
      );
    }

    // Check JSON database
    if (_database.containsKey(id)) {
      final entry = _database[id]!;
      return IngredientResult(
        ingredient: id.toUpperCase(),
        status: _parseStatus(entry['status']!),
        reason: entry['reason']!,
      );
    }

    return IngredientResult(
      ingredient: id.toUpperCase(),
      status: HalalStatus.doubtful,
      reason: 'This additive is not in our database.',
    );
  }

  /// Fallback: check by text against JSON database (only exact match).
  IngredientResult _checkByTextFallback(String text) {
    // Only exact match — no fuzzy matching to avoid false positives
    if (_database.containsKey(text)) {
      final entry = _database[text]!;
      return IngredientResult(
        ingredient: text,
        status: _parseStatus(entry['status']!),
        reason: entry['reason']!,
      );
    }

    // Check taxonomy ID sets with normalized text
    final asId = text.replaceAll(' ', '-');
    if (_haramIds.contains(asId)) {
      return IngredientResult(
        ingredient: text,
        status: HalalStatus.haram,
        reason: _getHaramReason(asId),
      );
    }
    if (_doubtfulIds.contains(asId)) {
      return IngredientResult(
        ingredient: text,
        status: HalalStatus.doubtful,
        reason: _getDoubtfulReason(asId),
      );
    }
    if (_halalIds.contains(asId)) {
      return IngredientResult(
        ingredient: text,
        status: HalalStatus.halal,
        reason: 'This ingredient is halal.',
      );
    }

    return IngredientResult(
      ingredient: text,
      status: HalalStatus.doubtful,
      reason: 'This ingredient is not in our database.',
    );
  }

  String _getHaramReason(String id) {
    final reasons = {
      'gelatin': 'Gelatin is often derived from pork or non-halal animals.',
      'gelatine': 'Gelatine is often derived from pork or non-halal animals.',
      'pork': 'Pork and pork derivatives are strictly prohibited.',
      'pork-meat': 'Pork meat is strictly haram.',
      'pork-fat': 'Pork fat is strictly haram.',
      'pork-gelatin': 'Pork gelatin is strictly haram.',
      'lard': 'Lard is rendered pig fat — haram.',
      'bacon': 'Bacon is a pork product — haram.',
      'ham': 'Ham is a pork product — haram.',
      'pepsin': 'Pepsin is usually from pork stomach lining.',
      'carmine': 'Carmine is derived from cochineal insects.',
      'carminic-acid': 'Carminic acid is derived from insects.',
      'cochineal': 'Cochineal is an insect-based coloring.',
      'alcohol': 'Alcohol as an ingredient is prohibited.',
      'ethanol': 'Ethanol is an intoxicant — haram.',
      'wine': 'Wine is an alcoholic beverage — haram.',
      'rum': 'Rum is an alcoholic beverage — haram.',
      'e120': 'E120 (Cochineal) is insect-derived — haram.',
      'e441': 'E441 (Gelatine) is often from non-halal sources.',
      'e542': 'E542 (Bone phosphate) from non-halal animal bones.',
      'e904': 'E904 (Shellac) is insect-derived.',
      'animal-fat': 'Animal fat from non-halal sources is haram.',
      'tallow': 'Tallow is rendered animal fat, often non-halal.',
      'blood': 'Blood and blood products are haram.',
      'l-cysteine': 'L-Cysteine may be derived from non-halal sources.',
    };
    return reasons[id] ?? 'This ingredient is considered haram.';
  }

  String _getDoubtfulReason(String id) {
    final reasons = {
      'whey': 'Whey may contain animal-derived rennet.',
      'whey-powder': 'Whey powder may contain animal-derived rennet.',
      'rennet': 'Rennet can be from calf stomach. Microbial rennet is halal.',
      'glycerin': 'Glycerin may be from animal or plant sources.',
      'glycerol': 'Glycerol may be animal-derived.',
      'cheese': 'Cheese may contain animal rennet.',
      'emulsifier': 'Emulsifiers may be from animal or plant sources.',
      'chicken': 'Chicken must be halal-slaughtered.',
      'beef': 'Beef must be from halal-slaughtered cattle.',
      'lamb': 'Lamb must be from halal-slaughtered animals.',
      'natural-flavoring': 'Natural flavoring may be from animal sources.',
      'e471': 'E471 may be from animal or plant fats.',
      'e476': 'E476 may be animal or plant-based.',
    };
    return reasons[id] ??
        'This ingredient may be from animal or plant sources. Verification needed.';
  }

  HalalStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'halal':
        return HalalStatus.halal;
      case 'haram':
        return HalalStatus.haram;
      case 'doubtful':
        return HalalStatus.doubtful;
      default:
        return HalalStatus.doubtful;
    }
  }

  /// Parses raw ingredients text into individual ingredients (fallback only).
  List<String> _parseIngredients(String text) {
    if (text.isEmpty) return [];

    String cleaned = text
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\d+(\.\d+)?%'), '')
        .replaceAll(RegExp(r'[*_#]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    final parts = cleaned.split(RegExp(r'[,;·•]'));

    return parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty && part.length > 1)
        .map((part) {
          return part
              .replaceAll(RegExp(r'^\d+\.\s*'), '')
              .replaceAll(RegExp(r':$'), '')
              .trim()
              .toLowerCase();
        })
        .where((part) => part.isNotEmpty && part.length > 1)
        .toList();
  }
}
