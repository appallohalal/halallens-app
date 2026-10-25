import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'halal_result.dart';
import 'product.dart';

/// Represents a scanned item stored in local history.
class HistoryItem {
  final String id;
  final String productName;
  final String barcode;
  final HalalStatus overallStatus;
  final DateTime scanDate;
  final bool isImageScan;
  final HalalResult halalResult;
  final Product? product;

  const HistoryItem({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.overallStatus,
    required this.scanDate,
    required this.isImageScan,
    required this.halalResult,
    this.product,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productName': productName,
      'barcode': barcode,
      'overallStatus': overallStatus.name,
      'scanDate': scanDate.toIso8601String(),
      'isImageScan': isImageScan,
      'halalResult': halalResult.toJson(),
      'product': product?.toJson(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] ?? '',
      productName: map['productName'] ?? 'general.unknown'.tr(),
      barcode: map['barcode'] ?? '',
      overallStatus: HalalStatus.values.firstWhere(
        (e) => e.name == map['overallStatus'],
        orElse: () => HalalStatus.doubtful,
      ),
      scanDate: DateTime.parse(map['scanDate'] as String),
      isImageScan: map['isImageScan'] ?? false,
      halalResult: HalalResult.fromJson(
        map['halalResult'] as Map<String, dynamic>,
      ),
      product: map['product'] != null
          ? Product.fromLocalJson(map['product'] as Map<String, dynamic>)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory HistoryItem.fromJson(String source) =>
      HistoryItem.fromMap(json.decode(source) as Map<String, dynamic>);
}
