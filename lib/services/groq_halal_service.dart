import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/groq_config.dart';
import '../models/halal_result.dart';
import '../models/product.dart';
import 'package:easy_localization/easy_localization.dart';

/// AI-powered halal analysis service integrated with Admin Additives Dictionary.
class GroqHalalService {
  bool _isInitialized = false;
  Map<String, Map<String, dynamic>> _adminAdditives = {};

  static const Map<String, String> _langNameToCode = {
    'english': 'en',
    'bengali': 'bn',
    'bangla': 'bn',
    'arabic': 'ar',
    'urdu': 'ur',
    'turkish': 'tr',
    'french': 'fr',
    'german': 'de',
    'spanish': 'es',
    'hindi': 'hi',
    'indonesian': 'id',
    'italian': 'it',
    'portuguese': 'pt',
    'russian': 'ru',
    'chinese': 'zh',
  };

  /// Initializes the Groq service by syncing with GroqConfig and Admin Additives.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await Future.wait([
      GroqConfig.syncFromBackend(),
      _syncAdminAdditives(),
    ]);
    _isInitialized = true;
  }

  /// Syncs the E-Numbers / Additives Dictionary from Supabase `additives` table.
  Future<void> _syncAdminAdditives() async {
    try {
      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/additives?select=*',
      );
      final res = await http
          .get(
            uri,
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final rows = json.decode(res.body) as List<dynamic>;
        final map = <String, Map<String, dynamic>>{};
        for (final r in rows) {
          if (r is Map<String, dynamic>) {
            final code = _normalizeECode(r['code']?.toString() ?? '');
            if (code.isNotEmpty) {
              map[code] = r;
            }
          }
        }
        _adminAdditives = map;
      }
    } catch (_) {}
  }

  String _normalizeECode(String raw) {
    return raw
        .toUpperCase()
        .replaceFirst('EN:', '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Extracts all E-numbers from the additives list and raw ingredients text.
  Set<String> extractECodes(List<String> additives, String ingredientsText) {
    final codes = <String>{};
    final eRegex = RegExp(r'^E\d{3,4}[A-Z]?$');
    for (final a in additives) {
      final norm = _normalizeECode(a);
      if (eRegex.hasMatch(norm)) {
        codes.add(norm);
      }
    }
    final textRegex = RegExp(r'\bE-?\d{3,4}[a-zA-Z]?\b', caseSensitive: false);
    for (final m in textRegex.allMatches(ingredientsText)) {
      final val = m.group(0);
      if (val != null) {
        codes.add(_normalizeECode(val));
      }
    }
    return codes;
  }

  /// Whether AI service is available (governed dynamically by GroqConfig).
  bool get isAvailable => _isInitialized && GroqConfig.isEnabled;

  /// Direct lookup if the user enters an E-number code (e.g. "E120", "E471") directly.
  Future<({Product product, HalalResult result})?> lookupSingleAdditive(
    String input, {
    String language = 'English',
  }) async {
    final norm = _normalizeECode(input.trim());
    if (!RegExp(r'^E\d{3,4}[A-Z]?$').hasMatch(norm)) return null;

    if (_adminAdditives.isEmpty) {
      await _syncAdminAdditives();
    }

    final row = _adminAdditives[norm];
    if (row == null) return null;

    final langCode = _langNameToCode[language.toLowerCase().trim()] ?? 'en';
    final rawStatus = (row['status']?.toString() ?? 'MUSHBOOH').toUpperCase();
    final status = rawStatus == 'HALAL'
        ? HalalStatus.halal
        : rawStatus == 'HARAM'
            ? HalalStatus.haram
            : HalalStatus.doubtful;

    final translations = row['translations'] as Map<String, dynamic>? ?? {};
    final trans =
        (translations[langCode] ?? translations['en']) as Map<String, dynamic>? ??
            {};
    final nameEn = row['name_en']?.toString() ?? norm;
    final localName = trans['name']?.toString();
    final displayName = (localName != null && localName.isNotEmpty)
        ? '$norm - $localName'
        : '$norm - $nameEn';
    final description = trans['description']?.toString() ?? '';
    final reason = (trans['halalReason']?.toString().isNotEmpty == true)
        ? trans['halalReason'].toString()
        : description.isNotEmpty
            ? description
            : 'Source: ${row['source'] ?? 'Verified'} (${row['category'] ?? 'Additive'})';

    final product = Product(
      barcode: norm,
      name: displayName,
      ingredients: description.isNotEmpty ? description : nameEn,
      additives: [norm],
      brands: row['category']?.toString() ?? 'Food Additive',
      manualStatus: rawStatus,
      moderatorNote: reason,
    );

    final ingResult = IngredientResult(
      ingredient: displayName,
      status: status,
      reason: reason,
    );

    final result = HalalResult(
      overallStatus: status,
      ingredientResults: [ingResult],
      haramIngredients: status == HalalStatus.haram ? [displayName] : [],
      doubtfulIngredients: status == HalalStatus.doubtful ? [displayName] : [],
      halalIngredients: status == HalalStatus.halal ? [displayName] : [],
    );

    return (product: product, result: result);
  }

  /// Analyzes product ingredients using server-managed Groq AI and Admin Additives.
  Future<HalalResult?> analyzeIngredients({
    required String productName,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    String? brand,
    String? imageUrl,
    String? imageBase64,
    String language = 'English',
    String? barcode,
  }) async {
    if (!isAvailable) return null;

    if (_adminAdditives.isEmpty) {
      await _syncAdminAdditives();
    }

    // 1. Primary approach: Call Backend Proxy Server
    try {
      final backendResult = await _analyzeViaBackend(
        productName: productName,
        brand: brand,
        imageUrl: imageUrl,
        ingredientsText: ingredientsText,
        parsedIngredients: parsedIngredients,
        additives: additives,
        imageBase64: imageBase64,
        language: language,
        barcode: barcode,
      );
      if (backendResult != null) {
        return _applyAdminAdditivesToResult(
          backendResult,
          additives: additives,
          ingredientsText: ingredientsText,
          language: language,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[GroqHalalService] Backend proxy request failed: $e. Falling back to direct resilient execution...',
        );
      }
    }

    // 2. Resilient Fallback: Direct execution using remote GroqConfig
    try {
      final directResult = await _analyzeViaDirectGroq(
        productName: productName,
        ingredientsText: ingredientsText,
        parsedIngredients: parsedIngredients,
        additives: additives,
        imageBase64: imageBase64,
        language: language,
        barcode: barcode,
      );
      if (directResult != null) {
        return _applyAdminAdditivesToResult(
          directResult,
          additives: additives,
          ingredientsText: ingredientsText,
          language: language,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GroqHalalService] Direct execution also failed: $e');
      }
      return null;
    }
  }

  /// Enforces Admin Additives Dictionary statuses & localized explanations on the final result.
  HalalResult _applyAdminAdditivesToResult(
    HalalResult baseResult, {
    required List<String> additives,
    required String ingredientsText,
    required String language,
  }) {
    final codes = extractECodes(additives, ingredientsText);
    if (codes.isEmpty || _adminAdditives.isEmpty) return baseResult;

    final langCode = _langNameToCode[language.toLowerCase().trim()] ?? 'en';
    final updatedIngredients = List<IngredientResult>.from(
      baseResult.ingredientResults,
    );
    bool modified = false;

    for (final code in codes) {
      final row = _adminAdditives[code];
      if (row == null) continue;

      modified = true;
      final rawStatus = (row['status']?.toString() ?? 'MUSHBOOH').toUpperCase();
      final status = rawStatus == 'HALAL'
          ? HalalStatus.halal
          : rawStatus == 'HARAM'
              ? HalalStatus.haram
              : HalalStatus.doubtful;

      final translations = row['translations'] as Map<String, dynamic>? ?? {};
      final trans = (translations[langCode] ?? translations['en'])
              as Map<String, dynamic>? ??
          {};
      final nameEn = row['name_en']?.toString() ?? code;
      final localName = trans['name']?.toString();
      final displayName = (localName != null && localName.isNotEmpty)
          ? '$code ($localName)'
          : '$code ($nameEn)';
      final reason = (trans['halalReason']?.toString().isNotEmpty == true)
          ? trans['halalReason'].toString()
          : (trans['description']?.toString().isNotEmpty == true)
              ? trans['description'].toString()
              : 'Source: ${row['source'] ?? 'Verified'} (${row['category'] ?? 'Additive'})';

      final existingIdx = updatedIngredients.indexWhere(
        (ir) => ir.ingredient.toUpperCase().contains(code),
      );
      if (existingIdx >= 0) {
        updatedIngredients[existingIdx] = IngredientResult(
          ingredient: updatedIngredients[existingIdx].ingredient,
          status: status,
          reason: reason,
        );
      } else {
        updatedIngredients.add(
          IngredientResult(
            ingredient: displayName,
            status: status,
            reason: reason,
          ),
        );
      }
    }

    if (!modified) return baseResult;

    final haramList = updatedIngredients
        .where((i) => i.status == HalalStatus.haram)
        .map((i) => i.ingredient)
        .toList();
    final doubtfulList = updatedIngredients
        .where((i) => i.status == HalalStatus.doubtful)
        .map((i) => i.ingredient)
        .toList();
    final halalList = updatedIngredients
        .where((i) => i.status == HalalStatus.halal)
        .map((i) => i.ingredient)
        .toList();

    final overall = haramList.isNotEmpty
        ? HalalStatus.haram
        : doubtfulList.isNotEmpty
            ? HalalStatus.doubtful
            : HalalStatus.halal;

    return HalalResult(
      overallStatus: overall,
      ingredientResults: updatedIngredients,
      haramIngredients: haramList,
      doubtfulIngredients: doubtfulList,
      halalIngredients: halalList,
    );
  }

  /// Primary: Route via backend server proxy (/api/v1/groq/analyze)
  Future<HalalResult?> _analyzeViaBackend({
    required String productName,
    String? brand,
    String? imageUrl,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    String? imageBase64,
    required String language,
    String? barcode,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/groq/analyze');
    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'productName': productName,
            'brand': ?brand,
            'imageUrl': ?imageUrl,
            'ingredientsText': ingredientsText,
            'parsedIngredients':
                parsedIngredients.map((e) => e.toJson()).toList(),
            'additives': additives,
            'imageBase64': ?imageBase64,
            'language': language,
            'barcode': ?barcode,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['result'] != null) {
        final resultJson = data['result'] as Map<String, dynamic>;
        if (resultJson['is_not_food'] == true) {
          return null;
        }
        return HalalResult.fromJson(resultJson);
      }
    }
    return null;
  }

  /// Resilient Fallback: Direct execution using parameters from GroqConfig
  Future<HalalResult?> _analyzeViaDirectGroq({
    required String productName,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    String? imageBase64,
    required String language,
    String? barcode,
  }) async {
    final startTime = DateTime.now();

    final apiKey = GroqConfig.apiKey;
    if (apiKey.isEmpty) return null;

    final modelName = imageBase64 != null
        ? GroqConfig.visionModel
        : GroqConfig.model;

    final prompt = _buildPrompt(
      productName: productName,
      ingredientsText: ingredientsText,
      parsedIngredients: parsedIngredients,
      additives: additives,
      hasImage: imageBase64 != null,
      language: language,
      barcode: barcode,
    );

    final List<Map<String, dynamic>> messages = [
      {
        'role': 'system',
        'content':
            'You are a Senior Halal Certification Auditor and Islamic Food Technologist. You specialize in identifying hidden animal derivatives, cross-contamination risks, and checking E-numbers against the latest Global Halal Standards. You MUST reply with ONLY valid JSON.',
      },
    ];

    if (imageBase64 != null) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
          },
        ],
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }

    final groqResponse = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'model': modelName,
            'messages': messages,
            'temperature': GroqConfig.temperature,
            'max_completion_tokens': GroqConfig.maxTokens,
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 20));

    final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

    _logTelemetry(
      model: modelName,
      barcode: barcode,
      latencyMs: latencyMs,
      statusCode: groqResponse.statusCode,
      status: groqResponse.statusCode == 200 ? 'SUCCESS' : 'ERROR',
      responseBody: groqResponse.body,
    );

    if (groqResponse.statusCode != 200) return null;

    final data = json.decode(groqResponse.body);
    final message = data['choices']?[0]?['message'] as Map<String, dynamic>?;
    final text = (message?['content'] ?? message?['reasoning'])?.toString();
    if (text == null || text.isEmpty) return null;

    return _parseResponse(text);
  }

  /// Logs telemetry asynchronously into Supabase groq_api_logs table
  void _logTelemetry({
    required String model,
    String? barcode,
    required int latencyMs,
    required int statusCode,
    required String status,
    required String responseBody,
  }) async {
    try {
      int promptTokens = 0;
      int completionTokens = 0;
      String? errorMessage;

      try {
        final parsed = json.decode(responseBody);
        if (statusCode == 200) {
          promptTokens = parsed['usage']?['prompt_tokens'] ?? 0;
          completionTokens = parsed['usage']?['completion_tokens'] ?? 0;
        } else {
          errorMessage = parsed['error']?['message'] ?? 'Status $statusCode';
        }
      } catch (_) {}

      await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/groq_api_logs'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'endpoint': '/openai/v1/chat/completions',
          'model': model,
          'barcode': barcode,
          'prompt_tokens': promptTokens,
          'completion_tokens': completionTokens,
          'latency_ms': latencyMs,
          'status_code': statusCode,
          'status': status,
          'error_message': errorMessage,
        }),
      );
    } catch (_) {}
  }

  /// Builds prompt for Groq AI
  String _buildPrompt({
    required String productName,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    bool hasImage = false,
    String language = 'English',
    String? barcode,
  }) {
    final ingredientLines = <String>[];

    for (final ing in parsedIngredients) {
      final vegan = ing.vegan != null ? ', vegan=${ing.vegan}' : '';
      final vegetarian =
          ing.vegetarian != null ? ', vegetarian=${ing.vegetarian}' : '';
      ingredientLines.add(
        '- ${ing.id} (display: "${ing.text}"$vegan$vegetarian)',
      );
    }

    final eCodes = extractECodes(additives, ingredientsText);
    if (eCodes.isNotEmpty) {
      ingredientLines.add('');
      ingredientLines.add('Additives: ${eCodes.join(", ")}');
    }

    if (ingredientLines.isEmpty && ingredientsText.isNotEmpty) {
      ingredientLines.add('Raw ingredient text: "$ingredientsText"');
    }

    String initialInstruction =
        'Analyze the provided product and its ingredients for Halal compliance based on universally accepted Islamic Dietary Laws (Shari\'ah). YOU MUST PROVIDE ALL REASONS AND SUMMARIES IN $language.';
    if (hasImage) {
      initialInstruction =
          'Analyze the provided image containing an ingredient label. Rigorously EXTRACT EVERY SINGLE INGREDIENT visible in the image (in ANY language) with the highest possible accuracy. Evaluate all extracted ingredients for Halal compliance based on universally accepted Islamic Dietary Laws (Shari\'ah). YOU MUST PROVIDE ALL REASONS AND SUMMARIES IN $language. Keep the original native name in the name field alongside the English translation if applicable.';
    }

    final isBarcodeProduct = barcode != null && barcode.isNotEmpty;
    final validationRule = (isBarcodeProduct || hasImage)
        ? '''*** COMMERCIAL PRODUCT CONTEXT ***
This is a recognized packaged market product (Barcode: "$barcode", Product: "$productName").
Evaluate all known ingredients and additives. If the ingredient list is partial or in summary form, use your knowledge base of commercial formulations for this product brand to identify potential animal derivatives, gelatin, emulsifiers (E471), or alcohol. Do NOT return "not_food".'''
        : '''*** CRITICAL VALIDATION RULE (MUST CHECK FIRST) ***
Before analyzing, you MUST first determine if the provided text actually contains real food/beverage ingredients.
If the input is ANY of the following, you MUST return the "not_food" response shown below:
- Random words, greetings, or single non-ingredient words (e.g. "hi", "hello", "test")
- Profanity, slang, or offensive language
- General sentences, messages, or conversations that are not ingredient lists
- Gibberish, nonsensical text, or text that does not resemble a food ingredient list
- Very short text (1-2 words) that is clearly not a food ingredient name

"not_food" Response (use when input is NOT a valid ingredient list):
{
  "overall_status": "not_food",
  "overall_reason": "The provided text does not contain recognizable food ingredients.",
  "ingredients": []
}

Only proceed with halal analysis if the text genuinely contains food ingredient names.
*** END VALIDATION RULE ***''';

    return '''
$initialInstruction

$validationRule

Product: "$productName"

Ingredients for Analysis:
${hasImage ? 'READ DIRECTLY FROM THE IMAGE PROVIDED' : ingredientLines.join('\n')}

Internal Logic for Classification:
1. "haram": 
   - ANY derivative of swine (pork, bacon, lard, pig-skin).
   - Intoxicants (Alcohol added as an ingredient, wine, beer).
   - Insects (except locusts); specifically flag E120 (Carmine) and E904 (Shellac).
   - Animal-derived ingredients without a declared Halal source (e.g. Pepsin from pork, Bone Phosphate E542).
2. "doubtful" (Mushbooh): 
   - Animal enzymes, emulsifiers (E471, E472), or stabilizers (Glycerin E422) where the source (plant vs animal) is not specified.
   - Whey or Cheese where the source of rennet/enzymes is unknown.
   - L-cysteine (E920) if the origin is not confirmed as plant-based.
3. "halal": 
   - Purely plant-based items, minerals, synthetic chemicals.
   - Dairy (from Halal animals), Fish, and Eggs.
   - Specifically confirm "Plant-based Lecithin" or "Soy Lecithin" as Halal.

Output JSON Structure (MANDATORY):
{
  "overall_status": "halal|haram|doubtful|not_food",
  "overall_reason": "Detailed summary of the entire product's status (IN $language).",
  "ingredients": [
    {
      "name": "Original Name",
      "status": "halal|haram|doubtful",
      "reason": "Expert technical/religious reason for this classification (IN $language)."
    }
  ]
}
''';
  }

  /// Parses JSON response into HalalResult
  HalalResult? _parseResponse(String responseText) {
    try {
      final data = json.decode(responseText) as Map<String, dynamic>;

      final overallStatusStr = data['overall_status']?.toString() ?? 'doubtful';
      if (overallStatusStr.toLowerCase().trim() == 'not_food') {
        return null;
      }

      final overallStatus = _parseStatus(overallStatusStr);
      final ingredientResults = <IngredientResult>[];
      final haramList = <String>[];
      final doubtfulList = <String>[];
      final halalList = <String>[];

      final ingredients = data['ingredients'] as List<dynamic>? ?? [];

      for (final ing in ingredients) {
        if (ing is Map<String, dynamic>) {
          final name = ing['name']?.toString() ?? 'general.unknown'.tr();
          final statusStr = ing['status']?.toString() ?? 'doubtful';
          final reason = ing['reason']?.toString() ?? 'result.no_reason'.tr();
          final status = _parseStatus(statusStr);

          ingredientResults.add(
            IngredientResult(ingredient: name, status: status, reason: reason),
          );

          switch (status) {
            case HalalStatus.haram:
              haramList.add(name);
              break;
            case HalalStatus.doubtful:
              doubtfulList.add(name);
              break;
            case HalalStatus.halal:
              halalList.add(name);
              break;
          }
        }
      }

      return HalalResult(
        overallStatus: overallStatus,
        ingredientResults: ingredientResults,
        haramIngredients: haramList,
        doubtfulIngredients: doubtfulList,
        halalIngredients: halalList,
      );
    } catch (_) {
      return null;
    }
  }

  HalalStatus _parseStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'halal':
        return HalalStatus.halal;
      case 'haram':
        return HalalStatus.haram;
      case 'doubtful':
      case 'mushbooh':
      case 'questionable':
      default:
        return HalalStatus.doubtful;
    }
  }
}
