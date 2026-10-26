import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/product.dart';
import '../models/halal_result.dart';
import '../services/api_service.dart';
import '../services/groq_halal_service.dart';
import '../services/history_service.dart';
import '../models/history_item.dart';
import 'package:easy_localization/easy_localization.dart';

/// State management provider for the scanner and product analysis flow.
///
/// Uses a hybrid approach:
/// 1. Primary: Groq AI for instant expert-level halal analysis
/// 2. Fallback: Local database + taxonomy ID matching
class ScannerProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GroqHalalService _groqService = GroqHalalService();

  Product? _product;
  HalalResult? _halalResult;
  bool _isLoading = false;
  String? _errorMessage;
  bool _usedAi = false;

  // Getters
  Product? get product => _product;
  HalalResult? get halalResult => _halalResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usedAi => _usedAi;
  bool get isAiEnabled => AppConfig.isAiEnabled;

  /// Initializes the provider and the Groq AI service.
  Future<void> initialize() async {
    try {
      // Initialize Groq AI if API key is configured
      if (AppConfig.isAiEnabled) {
        await _groqService.initialize();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '${"errors.init_failed".tr()}: $e';
      notifyListeners();
    }
  }

  /// Processes a scanned barcode: fetches product data and checks halal status using AI.
  Future<void> processBarcode(
    String barcode, {
    String language = 'English',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _product = null;
    _halalResult = null;
    _usedAi = false;
    notifyListeners();

    try {
      if (AppConfig.isAiEnabled && !_groqService.isAvailable) {
        await _groqService.initialize();
      }

      final fetchedProduct = await _apiService.fetchProduct(barcode);
      _product = fetchedProduct;

      if (_groqService.isAvailable) {
        final aiResult = await _groqService.analyzeIngredients(
          productName: fetchedProduct.name,
          ingredientsText: fetchedProduct.ingredients,
          parsedIngredients: fetchedProduct.parsedIngredients,
          additives: fetchedProduct.additives,
          language: language,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          _halalResult = aiResult;
          _usedAi = true;
          _isLoading = false;
          _saveToHistory(fetchedProduct.name, barcode, false);
          notifyListeners();
          return;
        } else {
          throw Exception("errors.analysis_failed".tr());
        }
      } else {
        throw Exception("errors.service_unavailable".tr());
      }
    } on ProductNotFoundException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = '${"errors.generic_error".tr()}: $e';
      notifyListeners();
    }
  }

  /// Processes raw ingredient text using AI.
  Future<void> processIngredientText(
    String ingredientText, {
    String language = 'English',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _product = null;
    _halalResult = null;
    _usedAi = false;
    notifyListeners();

    try {
      if (AppConfig.isAiEnabled && !_groqService.isAvailable) {
        await _groqService.initialize();
      }

      _product = Product(
        barcode: '',
        name: 'general.scanned_ingredients'.tr(),
        ingredients: ingredientText,
        additives: [],
        parsedIngredients: [],
      );

      if (_groqService.isAvailable) {
        final aiResult = await _groqService.analyzeIngredients(
          productName: 'general.scanned_ingredients'.tr(),
          ingredientsText: ingredientText,
          parsedIngredients: [],
          additives: [],
          language: language,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          _halalResult = aiResult;
          _usedAi = true;
          _isLoading = false;
          _saveToHistory('general.scanned_ingredients'.tr(), null, false);
          notifyListeners();
          return;
        } else {
          throw Exception("errors.not_food".tr());
        }
      } else {
        throw Exception("errors.service_unavailable".tr());
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = '${"errors.generic_error".tr()}: $e';
      notifyListeners();
    }
  }

  /// Processes an ingredient label image using AI Vision.
  Future<void> processIngredientImage(
    String imageBase64, {
    String language = 'English',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _product = null;
    _halalResult = null;
    _usedAi = false;
    notifyListeners();

    try {
      if (AppConfig.isAiEnabled && !_groqService.isAvailable) {
        await _groqService.initialize();
      }

      _product = Product(
        barcode: '',
        name: 'general.scanned_image'.tr(),
        ingredients: 'general.scanned_image'.tr(),
        additives: [],
        parsedIngredients: [],
      );

      if (_groqService.isAvailable) {
        final aiResult = await _groqService.analyzeIngredients(
          productName: 'general.scanned_image'.tr(),
          ingredientsText: '',
          parsedIngredients: [],
          additives: [],
          imageBase64: imageBase64,
          language: language,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          _halalResult = aiResult;

          _product = Product(
            barcode: '',
            name: 'general.scanned_image'.tr(),
            ingredients: aiResult.ingredientResults
                .map((i) => i.ingredient)
                .join(', '),
            additives: [],
            parsedIngredients: [],
          );

          _usedAi = true;
          _isLoading = false;
          _saveToHistory('general.scanned_image'.tr(), null, true);
          notifyListeners();
          return;
        } else {
          throw Exception("errors.not_food".tr());
        }
      } else {
        throw Exception("errors.service_unavailable".tr());
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = '${"errors.generic_error".tr()}: $e';
      notifyListeners();
    }
  }

  void reset() {
    _product = null;
    _halalResult = null;
    _errorMessage = null;
    _isLoading = false;
    _usedAi = false;
    notifyListeners();
  }

  void restoreFromHistory(HistoryItem item) {
    if (item.product != null) {
      _product = item.product;
    } else {
      _product = Product(
        barcode: item.barcode,
        name: item.productName,
        ingredients: '',
        additives: [],
      );
    }
    _halalResult = item.halalResult;
    _usedAi = true;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _saveToHistory(String name, String? barcode, bool isImage) {
    if (_product != null && _halalResult != null) {
      final docId = DateTime.now().millisecondsSinceEpoch.toString();
      final item = HistoryItem(
        id: docId,
        productName: name,
        barcode: barcode ?? '',
        overallStatus: _halalResult!.overallStatus,
        scanDate: DateTime.now(),
        isImageScan: isImage,
        halalResult: _halalResult!,
        product: _product,
      );
      HistoryService.addHistoryItem(item);
    }
  }
}
