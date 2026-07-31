import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction_model.dart';
import '../../../providers/transactions_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/trx_type_meta.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trx = ref.watch(transactionsProvider);
    final items = _filter == null
        ? trx.items
        : trx.items.where((t) => t.trxType == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/closing/history'),
            tooltip: 'Closing History',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                ...TrxTypeMeta.all.map((e) => _filterChip(e.value.label, e.key)),
              ],
            ),
          ),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(transactionsProvider.notifier).refresh(),
              child: trx.loading && trx.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            _EmptyState(),
                          ],
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 72),
                          itemBuilder: (_, i) {
                            final t = items[i];
                            final meta = TrxTypeMeta.get(t.trxType);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: meta.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(meta.icon, color: meta.color),
                              ),
                              title: Text(
                                meta.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    Formatters.dateTime(t.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  if (t.customerPhone != null ||
                                      (t.note?.isNotEmpty ?? false))
                                    Text(
                                      [
                                        if (t.customerPhone != null)
                                          t.customerPhone!,
                                        if (t.note?.isNotEmpty ?? false)
                                          t.note!,
                                      ].join(' • '),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    Formatters.signedCurrency(t.amount, t.isCredit),
                                    style: TextStyle(
                                      color: t.isCredit
                                          ? AppTheme.success
                                          : AppTheme.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (t.commission > 0)
                                    Text(
                                      '+ ${Formatters.currency(t.commission)}',
                                      style: const TextStyle(
                                        color: AppTheme.success,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => _showDetail(context, t),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/transactions/add');
          ref.read(transactionsProvider.notifier).refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Widget _filterChip(String label, String? type) {
    final selected = _filter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = selected ? null : type),
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        backgroundColor: AppTheme.surface,
        side: BorderSide(color: AppTheme.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showDetail(BuildContext context, TransactionModel t) {
    final meta = TrxTypeMeta.get(t.trxType);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: meta.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(meta.icon, color: meta.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          Formatters.dateTime(t.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.signedCurrency(t.amount, t.isCredit),
                    style: TextStyle(
                      color: t.isCredit ? AppTheme.success : AppTheme.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _row('Transaction ID', t.id),
              _row('Amount', Formatters.currency(t.amount)),
              if (t.commission > 0)
                _row('Commission', Formatters.currency(t.commission)),
              if (t.customerPhone != null)
                _row('Customer Phone', t.customerPhone!),
              if (t.note != null && t.note!.isNotEmpty)
                _row('Note', t.note!),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete transaction?'),
                            content: const Text(
                              'This will permanently remove the entry and '
                              'reverse the account balance changes.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: AppTheme.danger)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          Navigator.pop(context);
                          await ref
                              .read(transactionsProvider.notifier)
                              .delete(t.id);
                        }
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                      label: const Text('Delete',
                          style: TextStyle(color: AppTheme.danger)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No transactions yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the + button to record your first entry.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
