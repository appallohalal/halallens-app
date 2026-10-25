import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/halal_result.dart';
import '../models/product.dart';
import 'package:easy_localization/easy_localization.dart';

/// AI-powered halal analysis service using Groq.
///
/// Sends product ingredients to Groq AI for expert-level halal analysis.
/// Returns structured results with status and detailed reasoning instantly.
class GroqHalalService {
  bool _isInitialized = false;

  /// Initializes the Groq service.
  void initialize() {
    if (_isInitialized || !AppConfig.isAiEnabled) return;
    _isInitialized = true;
  }

  /// Whether the service is available.
  bool get isAvailable => _isInitialized && AppConfig.groqApiKey.isNotEmpty;

  /// Analyzes product ingredients using Groq AI.
  Future<HalalResult?> analyzeIngredients({
    required String productName,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    String? imageBase64,
    String language = 'English',
  }) async {
    if (!isAvailable) return null;

    try {
      final prompt = _buildPrompt(
        productName: productName,
        ingredientsText: ingredientsText,
        parsedIngredients: parsedIngredients,
        additives: additives,
        hasImage: imageBase64 != null,
        language: language,
      );

      final modelName = imageBase64 != null
          ? 'qwen/qwen3.8-27b'
          : 'openai/gpt-oss-120b';

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

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.groqApiKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': modelName,
          'messages': messages,
          'temperature': 0.1,
          'max_completion_tokens': 2048,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        var detail = 'Groq ${response.statusCode}';
        try {
          final error = json.decode(response.body);
          final message = error['error']?['message'];
          if (message is String && message.isNotEmpty) detail = message;
        } catch (_) {}
        throw Exception(detail);
      }

      final data = json.decode(response.body);
      final message = data['choices'][0]['message'] as Map<String, dynamic>;
      final text = (message['content'] ?? message['reasoning'])?.toString();

      if (text == null || text.isEmpty) {
        return null;
      }

      return _parseResponse(text);
    } catch (e) {
      // Silently fall back back to local database on AI failure
      return null;
    }
  }

  /// Builds a detailed prompt for Groq AI.
  String _buildPrompt({
    required String productName,
    required String ingredientsText,
    required List<ParsedIngredient> parsedIngredients,
    required List<String> additives,
    bool hasImage = false,
    String language = 'English',
  }) {
    // Build ingredient list for the prompt
    final ingredientLines = <String>[];

    for (final ing in parsedIngredients) {
      final vegan = ing.vegan != null ? ', vegan=${ing.vegan}' : '';
      final vegetarian = ing.vegetarian != null
          ? ', vegetarian=${ing.vegetarian}'
          : '';
      ingredientLines.add(
        '- ${ing.id} (display: "${ing.text}"$vegan$vegetarian)',
      );
    }

    if (additives.isNotEmpty) {
      ingredientLines.add('');
      ingredientLines.add('Additives: ${additives.join(", ")}');
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

    return '''
$initialInstruction

*** CRITICAL VALIDATION RULE (MUST CHECK FIRST) ***
Before analyzing, you MUST first determine if the provided text actually contains real food/beverage ingredients.
If the input is ANY of the following, you MUST return the "not_food" response shown below:
- Random words, greetings, or single non-ingredient words (e.g. "hi", "hello", "test")
- Profanity, slang, or offensive language (e.g. swear words — do NOT interpret them literally as food)
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
*** END VALIDATION RULE ***

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

Critical Audit Instructions:
- Cross-Reference: Check for "hidden" animal fats in snack foods (e.g., Mono-diglycerides).
- Professional Tone: Provide a clear "reason" for each ingredient based on its chemical/biological origin.
- Majority Rule: If the product is 100% plant-based but contains one minor "Natural Flavouring" of unknown source, mark "overall_status" as "halal" but add a note in the "overall_reason" about the minor doubtful item.
- Strict Haram: If even ONE tiny amount of pork or alcohol is present, the "overall_status" MUST be "haram".

Output JSON Structure (MANDATORY):
{
  "overall_status": "halal|haram|doubtful|not_food",
  "overall_reason": "Detailed summary of the entire product's status (IN $language).",
  "ingredients": [
    {
      "name": "Original Name",
      "status": "halal|haram|doubtful",
      "reason": "Expert techical/religious reason for this classification (IN $language)."
    }
  ]
}
''';
  }

  /// Parses the JSON response from Groq into a HalalResult.
  /// Returns null if AI determines the input is not a food ingredient list.
  HalalResult? _parseResponse(String responseText) {
    try {
      final data = json.decode(responseText) as Map<String, dynamic>;

      // Check if AI flagged input as not food ingredients
      final overallStatusStr = data['overall_status']?.toString() ?? 'doubtful';
      if (overallStatusStr.toLowerCase().trim() == 'not_food') {
        return null;
      }

      // Parse overall status
      final overallStatus = _parseStatus(overallStatusStr);

      // Parse individual ingredients
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
    } catch (e) {
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
        return HalalStatus.doubtful;
      default:
        return HalalStatus.doubtful;
    }
  }
}
