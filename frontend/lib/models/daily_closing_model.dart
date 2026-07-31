/// End-of-day reconciliation record.
///
/// Mirrors the backend `daily_closings` table. The `discrepancy` field is
/// `actual_cash - expected_cash` and is computed by the backend when the
/// closing is created. The owner reviews any non-zero discrepancy and flips
/// `isResolved` once the missing money is accounted for.
class DailyClosingModel {
  final String id;
  final String shopId;
  final DateTime date;
  final num expectedCash;
  final num actualCash;
  final num discrepancy;
  final num totalProfit;
  final bool isResolved;
  final DateTime? createdAt;

  const DailyClosingModel({
    required this.id,
    required this.shopId,
    required this.date,
    required this.expectedCash,
    required this.actualCash,
    required this.discrepancy,
    required this.totalProfit,
    required this.isResolved,
    this.createdAt,
  });

  /// `true` when the counted drawer cash does not match the system's
  /// expected cash. Drives a red warning banner in the UI.
  bool get hasMismatch => discrepancy != 0;

  factory DailyClosingModel.fromJson(Map<String, dynamic> json) {
    return DailyClosingModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      date: DateTime.parse(json['date'] as String),
      expectedCash: num.parse(json['expected_cash'].toString()),
      actualCash: num.parse(json['actual_cash'].toString()),
      discrepancy: num.parse(json['discrepancy'].toString()),
      totalProfit: num.parse(json['total_profit'].toString()),
      isResolved: json['is_resolved'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'date': date.toIso8601String(),
        'expected_cash': expectedCash,
        'actual_cash': actualCash,
        'discrepancy': discrepancy,
        'total_profit': totalProfit,
        'is_resolved': isResolved,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
