/// A business "pocket" that holds funds.
///
/// Matches the backend `accounts` table. Each shop has three account types
/// by convention: agent_bKash, personal_bKash, physical_cash. The balance
/// is updated atomically by the backend on every transaction write.
class AccountModel {
  final String id;
  final String shopId;
  final String accountType;
  final num balance;
  final DateTime lastUpdated;

  const AccountModel({
    required this.id,
    required this.shopId,
    required this.accountType,
    required this.balance,
    required this.lastUpdated,
  });

  /// Convenience flag for the UI to colour-code bKash vs cash accounts.
  bool get isBkash =>
      accountType == 'agent_bKash' || accountType == 'personal_bKash';

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      accountType: json['account_type'] as String,
      balance: num.parse(json['balance'].toString()),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'account_type': accountType,
        'balance': balance,
        'last_updated': lastUpdated.toIso8601String(),
      };
}
