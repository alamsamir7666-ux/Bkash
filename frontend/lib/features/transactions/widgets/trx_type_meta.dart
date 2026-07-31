import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

/// Visual helper that picks an icon + colour for a given transaction type.
class TrxTypeMeta {
  const TrxTypeMeta._(this.label, this.icon, this.color, this.description);

  final String label;
  final IconData icon;
  final Color color;
  final String description;

  static const Map<String, TrxTypeMeta> _map = {
    'cash_in': TrxTypeMeta._(
      'Cash In',
      Icons.south_west,
      AppTheme.success,
      'Customer hands you cash; you send money from your bKash to theirs.',
    ),
    'cash_out': TrxTypeMeta._(
      'Cash Out',
      Icons.north_east,
      AppTheme.danger,
      'Customer gives bKash balance; you hand them physical cash.',
    ),
    'b2b_receive': TrxTypeMeta._(
      'B2B Receive',
      Icons.download,
      AppTheme.secondary,
      'Received bKash balance from another agent/shop.',
    ),
    'b2b_send': TrxTypeMeta._(
      'B2B Send',
      Icons.upload,
      AppTheme.secondary,
      'Sent bKash balance to another agent/shop.',
    ),
    'send_money': TrxTypeMeta._(
      'Send Money',
      Icons.send,
      AppTheme.primary,
      'Transfer bKash balance to a personal account.',
    ),
    'expense': TrxTypeMeta._(
      'Expense',
      Icons.money_off,
      AppTheme.warning,
      'Spent cash on shop supplies, rent, or other costs.',
    ),
    'capital_add': TrxTypeMeta._(
      'Add Capital',
      Icons.savings,
      AppTheme.primary,
      'Owner injects fresh funds from personal pocket into the shop.',
    ),
  };

  static TrxTypeMeta get(String type) =>
      _map[type] ?? TrxTypeMeta._(Formatters.trxTypeLabel(type), Icons.receipt, AppTheme.primary, '');

  static List<MapEntry<String, TrxTypeMeta>> get all => _map.entries.toList();
}
