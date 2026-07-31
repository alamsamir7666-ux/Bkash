import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/transaction_model.dart';

/// Compact ledger row showing transaction type, amount, and time.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final TransactionModel transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color = isCredit ? AppTheme.success : AppTheme.danger;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _iconFor(transaction.trxType),
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        Formatters.trxTypeLabel(transaction.trxType),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        [
          if (transaction.customerPhone != null) transaction.customerPhone!,
          Formatters.dateTime(transaction.createdAt),
        ].join(' • '),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Formatters.signedCurrency(transaction.amount, isCredit),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (transaction.commission > 0)
            Text(
              '+ ${Formatters.currency(transaction.commission)}',
              style: const TextStyle(
                color: AppTheme.success,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'cash_in':
        return Icons.south_west;
      case 'cash_out':
        return Icons.north_east;
      case 'b2b_receive':
        return Icons.download;
      case 'b2b_send':
        return Icons.upload;
      case 'send_money':
        return Icons.send;
      case 'expense':
        return Icons.money_off;
      case 'capital_add':
        return Icons.savings;
      default:
        return Icons.receipt;
    }
  }
}
