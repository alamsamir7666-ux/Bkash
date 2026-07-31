import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/account_model.dart';

/// A single coloured card showing the balance of one account pocket.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.account,
    required this.onTap,
  });

  final AccountModel account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(account.accountType);
    final icon = _iconFor(account.accountType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.85)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 14,
                ),
              ],
            ),
            const Spacer(),
            Text(
              Formatters.accountTypeLabel(account.accountType),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.currency(account.balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updated ${Formatters.time(account.lastUpdated)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'agent_bKash':
        return AppTheme.primary;
      case 'personal_bKash':
        return AppTheme.secondary;
      case 'physical_cash':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'agent_bKash':
      case 'personal_bKash':
        return Icons.account_balance_wallet;
      case 'physical_cash':
        return Icons.payments_outlined;
      default:
        return Icons.wallet;
    }
  }
}
