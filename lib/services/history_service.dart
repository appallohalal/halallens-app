import 'package:hive_flutter/hive_flutter.dart';
import '../models/history_item.dart';

class HistoryService {
  static const String _boxName = 'scan_history';

  // Private constructor
  HistoryService._();

  /// Initialize Hive and open the history box
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
    } catch (_) {}
  }

  /// Add a new scan to history
  static Future<void> addHistoryItem(HistoryItem item) async {
    final box = Hive.box<String>(_boxName);
    await box.put(item.id, item.toJson());
  }

  /// Get all history items sorted by date (newest first)
  static List<HistoryItem> getAllHistory() {
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

  /// Delete a single scan record
  static Future<void> deleteHistoryItem(String id) async {
    final box = Hive.box<String>(_boxName);
    await box.delete(id);
  }

  /// Clear all history
  static Future<void> clearAllHistory() async {
    final box = Hive.box<String>(_boxName);
    await box.clear();
  }
}
