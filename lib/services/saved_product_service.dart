import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_item.dart';

class SavedProductService {
  static const String _boxName = 'saved_products';

  // Private constructor
  SavedProductService._();

  /// Initialize Hive and open the saved products box
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
    } catch (_) {}
  }

  /// Check if a product is saved based on barcode or name
  static bool isSaved(String id) {
    if (!Hive.isBoxOpen(_boxName)) return false;
    final box = Hive.box<String>(_boxName);
    return box.containsKey(id);
  }

  /// Add a new product to saved list
  static Future<void> addSavedProduct(HistoryItem item) async {
    final box = Hive.box<String>(_boxName);
    // Use barcode as ID if available, otherwise use a combination of name or the generated ID
    final saveId = item.barcode.isNotEmpty ? item.barcode : item.id;
    await box.put(saveId, item.toJson());
  }

  /// Remove a saved product
  static Future<void> removeSavedProduct(String id) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(id);
  }

  /// Toggle saved status
  static Future<bool> toggleSavedStatus(HistoryItem item) async {
    final saveId = item.barcode.isNotEmpty ? item.barcode : item.id;
    if (isSaved(saveId)) {
      await removeSavedProduct(saveId);
      return false; // Not saved anymore
    } else {
      await addSavedProduct(item);
      return true; // Now saved
    }
  }

  /// Get all saved products sorted by date
  static List<HistoryItem> getAllSavedProducts() {
    if (!Hive.isBoxOpen(_boxName)) return [];

    final box = Hive.box<String>(_boxName);
    final List<HistoryItem> items = [];

    for (final value in box.values) {
      try {
        items.add(HistoryItem.fromJson(value));
      } catch (e) {
        // Skip corrupted data
      }
    }

    // Sort descending by date
    items.sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return items;
  }

  /// Clear all saved products
  static Future<void> clearAllSavedProducts() async {
    final box = Hive.box<String>(_boxName);
    await box.clear();
  }
}
