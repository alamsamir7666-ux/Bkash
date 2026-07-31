/// A single ledger entry — every taka in or out of the shop.
///
/// Mirrors the backend `transactions` table. The `trxType` enum drives UI
/// colour-coding and icon selection; `commission` is the profit earned on
/// the transaction (defaults to 0 for non-bKash transactions).
class TransactionModel {
  final String id;
  final String shopId;
  final String trxType;
  final num amount;
  final num commission;
  final String? sourceAccountId;
  final String? targetAccountId;
  final String? customerPhone;
  final String? note;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.shopId,
    required this.trxType,
    required this.amount,
    this.commission = 0,
    this.sourceAccountId,
    this.targetAccountId,
    this.customerPhone,
    this.note,
    required this.createdAt,
  });

  /// `true` if this transaction increases shop holdings (credit).
  /// Used to decide +/- sign in the ledger list.
  bool get isCredit =>
      trxType == 'cash_in' ||
      trxType == 'b2b_receive' ||
      trxType == 'capital_add';

  /// `true` if this transaction decreases shop holdings (debit).
  bool get isDebit => !isCredit;

  /// Whether the transaction type is eligible to earn a commission.
  bool get hasCommission =>
      trxType == 'cash_in' ||
      trxType == 'cash_out' ||
      trxType == 'b2b_receive' ||
      trxType == 'b2b_send' ||
      trxType == 'send_money';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      shopId: json['shop_id'] as String,
      trxType: json['trx_type'] as String,
      amount: num.parse(json['amount'].toString()),
      commission: json['commission'] != null
          ? num.parse(json['commission'].toString())
          : 0,
      sourceAccountId: json['source_account'] as String?,
      targetAccountId: json['target_account'] as String?,
      customerPhone: json['customer_phone'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shop_id': shopId,
        'trx_type': trxType,
        'amount': amount,
        'commission': commission,
        'source_account': sourceAccountId,
        'target_account': targetAccountId,
        'customer_phone': customerPhone,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}
