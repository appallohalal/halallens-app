import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/product.dart';
import '../models/halal_result.dart';
import '../services/api_service.dart';
import '../services/groq_halal_service.dart';
import '../services/history_service.dart';
import '../models/history_item.dart';
import 'package:easy_localization/easy_localization.dart';

/// State management provider for the scanner and product analysis flow.
class ScannerProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GroqHalalService _groqService = GroqHalalService();

  Product? _product;
  HalalResult? _halalResult;
  bool _isLoading = false;
  String? _errorMessage;
  bool _usedAi = false;
  String? _lastScannedBarcode;

  // Getters
  Product? get product => _product;
  HalalResult? get halalResult => _halalResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usedAi => _usedAi;
  bool get isAiEnabled => AppConfig.isAiEnabled;
  String? get lastScannedBarcode => _lastScannedBarcode;

  /// Initializes the provider and the Groq AI service.
  Future<void> initialize() async {
    try {
      if (AppConfig.isAiEnabled) {
        await _groqService.initialize();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '${"errors.init_failed".tr()}: $e';
      notifyListeners();
    }
  }

  /// Processes a scanned barcode or E-number ID: fetches product data and checks halal status.
  Future<void> processBarcode(
    String barcode, {
    String language = 'French',
  }) async {
    final cleanBarcode = barcode.trim();
    _lastScannedBarcode = cleanBarcode;
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

      // Check if user entered an E-number code directly (e.g. "E120", "E471")
      final additiveLookup = await _groqService.lookupSingleAdditive(
        cleanBarcode,
        language: language,
      );
      if (additiveLookup != null) {
        _product = additiveLookup.product;
        _halalResult = additiveLookup.result;
        _usedAi = true;
        _isLoading = false;
        _saveToHistory(additiveLookup.product.name, cleanBarcode, false);
        notifyListeners();
        return;
      }

      final fetchedProduct = await _apiService.fetchProduct(cleanBarcode);
      _product = fetchedProduct;

      HalalStatus? overrideStatus;
      final ms = fetchedProduct.manualStatus?.toUpperCase().trim();
      if (ms == 'HALAL') {
        overrideStatus = HalalStatus.halal;
      } else if (ms == 'HARAM') {
        overrideStatus = HalalStatus.haram;
      } else if (ms == 'MUSHBOOH' || ms == 'DOUBTFUL') {
        overrideStatus = HalalStatus.doubtful;
      }

      if (_groqService.isAvailable) {
        final aiResult = await _groqService.analyzeIngredients(
          productName: fetchedProduct.name,
          brand: fetchedProduct.brands,
          imageUrl: fetchedProduct.imageUrl,
          ingredientsText: fetchedProduct.ingredients,
          parsedIngredients: fetchedProduct.parsedIngredients,
          additives: fetchedProduct.additives,
          language: language,
          barcode: cleanBarcode,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          final cert = fetchedProduct.certifier ?? aiResult.certifier;
          final isCert = fetchedProduct.isCertified || aiResult.isCertified;
          final isOfficial = fetchedProduct.verifiedOfficial || aiResult.verifiedOfficial;

          // Product Status Logic: A product featuring a recognized certification organization
          // should not automatically default to "Mushbooh" (Doubtful). It displays as "HALAL" (green)
          // as soon as the official certifier is identified.
          HalalStatus resolvedStatus = aiResult.overallStatus;
          List<IngredientResult> resolvedIngredients = List.from(aiResult.ingredientResults);
          List<String> resolvedDoubtful = List.from(aiResult.doubtfulIngredients);
          List<String> resolvedHalal = List.from(aiResult.halalIngredients);

          if ((isCert || (cert != null && cert.isNotEmpty)) &&
              overrideStatus == null &&
              resolvedStatus != HalalStatus.haram &&
              aiResult.haramIngredients.isEmpty) {
            resolvedStatus = HalalStatus.halal;
            for (int i = 0; i < resolvedIngredients.length; i++) {
              if (resolvedIngredients[i].status == HalalStatus.doubtful) {
                resolvedIngredients[i] = IngredientResult(
                  ingredient: resolvedIngredients[i].ingredient,
                  status: HalalStatus.halal,
                  reason: cert != null && cert.isNotEmpty
                      ? '${resolvedIngredients[i].reason} (Validé sous certification $cert)'
                      : resolvedIngredients[i].reason,
                );
              }
            }
            resolvedHalal.addAll(resolvedDoubtful);
            resolvedDoubtful.clear();
          }

          final effectiveAiResult = HalalResult(
            overallStatus: resolvedStatus,
            ingredientResults: resolvedIngredients,
            haramIngredients: aiResult.haramIngredients,
            doubtfulIngredients: resolvedDoubtful,
            halalIngredients: resolvedHalal,
            certifier: cert,
            isCertified: isCert,
            verifiedOfficial: isOfficial,
            certificationDetails: fetchedProduct.certificationDetails ??
                aiResult.certificationDetails,
            isEstimated: aiResult.isEstimated,
          );

          _halalResult = overrideStatus != null
              ? _enforceProductStatus(effectiveAiResult, overrideStatus, fetchedProduct)
              : effectiveAiResult;
          _usedAi = true;
          _isLoading = false;
          _saveToHistory(fetchedProduct.name, cleanBarcode, false);
          _syncScannedProductToSupabase(fetchedProduct, _halalResult!);
          notifyListeners();
          return;
        }
      }

      // If product has a verified status or recognized certifier, return verdict directly
      final bool hasCert = fetchedProduct.isCertified ||
          (fetchedProduct.certifier != null && fetchedProduct.certifier!.isNotEmpty);
      final HalalStatus? directStatus = overrideStatus ?? (hasCert ? HalalStatus.halal : null);

      if (directStatus != null) {
        final rawList = fetchedProduct.ingredients
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final note = (fetchedProduct.moderatorNote?.isNotEmpty == true)
            ? fetchedProduct.moderatorNote!
            : (hasCert
                ? 'Certifié Halal par ${fetchedProduct.certifier ?? 'Organisme reconnu'}'
                : 'Vérifié par Allo Halal');
        final items = rawList.isNotEmpty ? rawList : [fetchedProduct.name];
        final ingResults = items
            .map(
              (item) => IngredientResult(
                ingredient: item,
                status: directStatus,
                reason: note,
              ),
            )
            .toList();
        _halalResult = HalalResult(
          overallStatus: directStatus,
          ingredientResults: ingResults,
          haramIngredients: directStatus == HalalStatus.haram ? items : [],
          doubtfulIngredients:
              directStatus == HalalStatus.doubtful ? items : [],
          halalIngredients: directStatus == HalalStatus.halal ? items : [],
          certifier: fetchedProduct.certifier,
          isCertified: fetchedProduct.isCertified,
          verifiedOfficial: fetchedProduct.verifiedOfficial,
          certificationDetails: fetchedProduct.certificationDetails,
        );
        _usedAi = false;
        _isLoading = false;
        _saveToHistory(fetchedProduct.name, cleanBarcode, false);
        _syncScannedProductToSupabase(fetchedProduct, _halalResult!);
        notifyListeners();
        return;
      }

      throw Exception("errors.analysis_failed".tr());
    } on ProductNotFoundException catch (e) {
      _isLoading = false;
      _lastScannedBarcode = e.barcode ?? cleanBarcode;
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

  /// Ensures the ingredient breakdown, counters, and overall status strictly match
  /// the status configured in the Admin Panel (`HALAL`, `HARAM`, or `MUSHBOOH`).
  HalalResult _enforceProductStatus(
    HalalResult aiResult,
    HalalStatus targetStatus,
    Product product,
  ) {
    final note = (product.moderatorNote?.isNotEmpty == true)
        ? product.moderatorNote!
        : 'Vérifié par Allo Halal';

    final updated = List<IngredientResult>.from(aiResult.ingredientResults);

    if (targetStatus == HalalStatus.halal) {
      for (int i = 0; i < updated.length; i++) {
        if (updated[i].status != HalalStatus.halal) {
          updated[i] = IngredientResult(
            ingredient: updated[i].ingredient,
            status: HalalStatus.halal,
            reason: note,
          );
        }
      }
    } else if (targetStatus == HalalStatus.haram) {
      final hasHaram = updated.any((i) => i.status == HalalStatus.haram);
      if (!hasHaram) {
        // Promote any doubtful ingredient to haram or prepend the admin verification note
        bool promoted = false;
        for (int i = 0; i < updated.length; i++) {
          if (updated[i].status == HalalStatus.doubtful) {
            updated[i] = IngredientResult(
              ingredient: updated[i].ingredient,
              status: HalalStatus.haram,
              reason: note,
            );
            promoted = true;
          }
        }
        if (!promoted) {
          updated.insert(
            0,
            IngredientResult(
              ingredient: product.name,
              status: HalalStatus.haram,
              reason: note,
            ),
          );
        }
      }
    } else if (targetStatus == HalalStatus.doubtful) {
      for (int i = 0; i < updated.length; i++) {
        if (updated[i].status == HalalStatus.haram) {
          updated[i] = IngredientResult(
            ingredient: updated[i].ingredient,
            status: HalalStatus.doubtful,
            reason: note,
          );
        }
      }
      final hasDoubtful = updated.any((i) => i.status == HalalStatus.doubtful);
      if (!hasDoubtful) {
        updated.insert(
          0,
          IngredientResult(
            ingredient: product.name,
            status: HalalStatus.doubtful,
            reason: note,
          ),
        );
      }
    }

    final haramList = updated
        .where((i) => i.status == HalalStatus.haram)
        .map((i) => i.ingredient)
        .toList();
    final doubtfulList = updated
        .where((i) => i.status == HalalStatus.doubtful)
        .map((i) => i.ingredient)
        .toList();
    final halalList = updated
        .where((i) => i.status == HalalStatus.halal)
        .map((i) => i.ingredient)
        .toList();

    return HalalResult(
      overallStatus: targetStatus,
      ingredientResults: updated,
      haramIngredients: haramList,
      doubtfulIngredients: doubtfulList,
      halalIngredients: halalList,
      certifier: product.certifier ?? aiResult.certifier,
      isCertified: product.isCertified || aiResult.isCertified,
      verifiedOfficial: product.verifiedOfficial || aiResult.verifiedOfficial,
      certificationDetails: product.certificationDetails ?? aiResult.certificationDetails,
    );
  }

  /// Processes raw ingredient text using AI (or barcode / E-number if typed here).
  Future<void> processIngredientText(
    String ingredientText, {
    String language = 'French',
    String? barcode,
  }) async {
    final trimmed = ingredientText.trim();
    if (barcode != null && barcode.isNotEmpty) {
      _lastScannedBarcode = barcode.trim();
    }

    // If user typed a numeric barcode in the text box, process it as a barcode
    if (RegExp(r'^\d{6,14}$').hasMatch(trimmed)) {
      await processBarcode(trimmed, language: language);
      return;
    }

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

      // If user typed a single E-number code (e.g. "E120"), return Admin Additive ruling
      final additiveLookup = await _groqService.lookupSingleAdditive(
        trimmed,
        language: language,
      );
      if (additiveLookup != null) {
        _product = additiveLookup.product;
        _halalResult = additiveLookup.result;
        _usedAi = true;
        _isLoading = false;
        _saveToHistory(additiveLookup.product.name, trimmed, false);
        notifyListeners();
        return;
      }

      _product = Product(
        barcode: barcode ?? '',
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
          barcode: barcode,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          _halalResult = aiResult;
          _usedAi = true;
          _isLoading = false;
          _saveToHistory('general.scanned_ingredients'.tr(), barcode, false);
          if (barcode != null && barcode.isNotEmpty) {
            _syncScannedProductToSupabase(_product!, _halalResult!);
          }
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
    String base64Image, {
    String language = 'French',
    String? barcode,
  }) async {
    if (barcode != null && barcode.isNotEmpty) {
      _lastScannedBarcode = barcode.trim();
    }
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
        barcode: barcode ?? '',
        name: 'general.scanned_image'.tr(),
        ingredients: 'result.analyzing_image_label'.tr(),
        additives: [],
        parsedIngredients: [],
      );
      notifyListeners();

      if (_groqService.isAvailable) {
        final aiResult = await _groqService.analyzeIngredients(
          productName: 'general.scanned_image'.tr(),
          ingredientsText: '',
          parsedIngredients: [],
          additives: [],
          imageBase64: base64Image,
          language: language,
          barcode: barcode,
        );

        if (aiResult != null && aiResult.ingredientResults.isNotEmpty) {
          _halalResult = aiResult;
          _product = Product(
            barcode: barcode ?? '',
            name: 'general.scanned_image'.tr(),
            ingredients: aiResult.ingredientResults
                .map((i) => i.ingredient)
                .join(', '),
            additives: [],
            parsedIngredients: [],
          );

          _usedAi = true;
          _isLoading = false;
          _saveToHistory('general.scanned_image'.tr(), barcode, true);
          if (barcode != null && barcode.isNotEmpty) {
            _syncScannedProductToSupabase(_product!, _halalResult!);
          }
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

  /// Automatically syncs any scanned barcode product to Supabase `products` table
  /// so it appears in the Admin Panel's Product Catalog for moderation/override.
  Future<void> _syncScannedProductToSupabase(
    Product product,
    HalalResult result,
  ) async {
    final code = product.barcode.trim();
    if (code.isEmpty) return;

    try {
      final checkUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/products?barcode=eq.$code&select=id,scans_count&limit=1',
      );
      final checkRes = await http
          .get(
            checkUri,
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (checkRes.statusCode == 200) {
        final rows = json.decode(checkRes.body) as List<dynamic>;
        if (rows.isNotEmpty) {
          final existing = rows.first as Map<String, dynamic>;
          final id = existing['id'];
          final currentScans = (existing['scans_count'] as num?)?.toInt() ?? 0;
          await http.patch(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/products?id=eq.$id'),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'Content-Type': 'application/json',
              'Prefer': 'return=minimal',
            },
            body: json.encode({
              'scans_count': currentScans + 1,
              'updated_at': DateTime.now().toIso8601String(),
            }),
          );
          return;
        }
      }

      final dbAiStatus = result.overallStatus == HalalStatus.halal
          ? 'HALAL'
          : result.overallStatus == HalalStatus.haram
              ? 'HARAM'
              : 'MUSHBOOH';
      final detectedECodes = _groqService
          .extractECodes(product.additives, product.ingredients)
          .toList();

      await http.post(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/products'),
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: json.encode({
          'barcode': code,
          'name': product.name,
          'brand': product.brands ?? '',
          'image_url': product.imageUrl,
          'ingredients_raw': product.ingredients,
          'detected_additives': detectedECodes,
          'ai_status': dbAiStatus,
          'is_overridden': false,
          'scans_count': 1,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }
}
