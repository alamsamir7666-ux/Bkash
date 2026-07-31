import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/account_model.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/trx_type_meta.dart';

/// Form screen for recording a new ledger entry.
///
/// The form adapts to the chosen transaction type: commission field is only
/// shown when the type is eligible, and source / target account dropdowns
/// are pre-filled based on which way the money flows.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _trxType = 'cash_in';
  String? _sourceAccountId;
  String? _targetAccountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _commissionCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _trxType = type;
      _sourceAccountId = null;
      _targetAccountId = null;
      // Auto-pick sensible source/target defaults
      final accounts = ref.read(accountsProvider).accounts;
      if (accounts.isNotEmpty) {
        switch (type) {
          case 'cash_in':
            // Customer cash -> agent bKash (money goes into agent_bKash)
            _targetAccountId = _byType(accounts, 'agent_bKash')?.id;
            _sourceAccountId = _byType(accounts, 'physical_cash')?.id;
            break;
          case 'cash_out':
            _sourceAccountId = _byType(accounts, 'agent_bKash')?.id;
            _targetAccountId = _byType(accounts, 'physical_cash')?.id;
            break;
          case 'b2b_receive':
            _targetAccountId = _byType(accounts, 'agent_bKash')?.id;
            _sourceAccountId = _byType(accounts, 'personal_bKash')?.id;
            break;
          case 'b2b_send':
            _sourceAccountId = _byType(accounts, 'agent_bKash')?.id;
            break;
          case 'send_money':
            _sourceAccountId = _byType(accounts, 'agent_bKash')?.id;
            _targetAccountId = _byType(accounts, 'personal_bKash')?.id;
            break;
          case 'expense':
            _sourceAccountId = _byType(accounts, 'physical_cash')?.id;
            break;
          case 'capital_add':
            _targetAccountId = _byType(accounts, 'physical_cash')?.id;
            break;
        }
      }
    });
  }

  AccountModel? _byType(List<AccountModel> accounts, String type) {
    return accounts.where((a) => a.accountType == type).firstOrNull;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final commission = _commissionCtrl.text.trim().isEmpty
        ? 0.0
        : num.tryParse(_commissionCtrl.text.trim()) ?? 0.0;

    final ok = await ref.read(transactionsProvider.notifier).create(
          trxType: _trxType,
          amount: num.parse(_amountCtrl.text.trim()),
          commission: commission,
          sourceAccountId: _sourceAccountId,
          targetAccountId: _targetAccountId,
          customerPhone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction recorded'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(transactionsProvider).error ??
              'Failed to record transaction'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final trx = ref.watch(transactionsProvider);
    final meta = TrxTypeMeta.get(_trxType);

    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Trx type selector
              Text('Transaction Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TrxTypeMeta.all.map((entry) {
                  final selected = _trxType == entry.key;
                  final m = entry.value;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => _onTypeChanged(entry.key),
                    label: Text(m.label),
                    avatar: Icon(m.icon, size: 16,
                        color: selected ? Colors.white : m.color),
                    selectedColor: m.color,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: m.color.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(meta.icon, color: meta.color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta.description,
                        style: TextStyle(
                          color: meta.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppTextField(
                label: 'Amount (BDT)',
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.payments,
                validator: Validators.amount,
              ),
              const SizedBox(height: 14),

              // Commission (only for eligible types)
              if (meta.label == 'Cash In' ||
                  meta.label == 'Cash Out' ||
                  meta.label == 'B2B Receive' ||
                  meta.label == 'B2B Send' ||
                  meta.label == 'Send Money') ...[
                AppTextField(
                  label: 'Commission (optional)',
                  controller: _commissionCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.savings,
                  hint: '0.00',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = num.tryParse(v.trim());
                    if (n == null) return 'Enter a valid number';
                    if (n < 0) return 'Commission cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Source account
              _AccountDropdown(
                label: 'From Account (source)',
                value: _sourceAccountId,
                accounts: accounts.accounts,
                enabled: _trxType != 'capital_add' && _trxType != 'b2b_receive',
                hint: _trxType == 'capital_add'
                    ? 'Owner\'s pocket (no system account)'
                    : 'Select source',
                onChanged: (v) => setState(() => _sourceAccountId = v),
              ),
              const SizedBox(height: 14),

              _AccountDropdown(
                label: 'To Account (target)',
                value: _targetAccountId,
                accounts: accounts.accounts,
                hint: 'Select target',
                onChanged: (v) => setState(() => _targetAccountId = v),
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Customer Phone (optional)',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
                validator: Validators.phone,
                hint: '01XXXXXXXXX',
              ),
              const SizedBox(height: 14),

              AppTextField(
                label: 'Note (optional)',
                controller: _noteCtrl,
                maxLines: 2,
                prefixIcon: Icons.notes,
                hint: 'e.g., "Monthly shop rent"',
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Record Transaction',
                icon: Icons.save,
                loading: trx.submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<AccountModel> accounts;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
      ),
      items: accounts
          .map((a) => DropdownMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    Text(Formatters.accountTypeLabel(a.accountType)),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.currency(a.balance),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: (v) {
        if (!enabled) return null;
        if (v == null || v.isEmpty) return 'Please select an account';
        return null;
      },
    );
  }
}
