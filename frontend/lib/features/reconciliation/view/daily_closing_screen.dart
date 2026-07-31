import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/closing_provider.dart';
import '../../../shared/widgets/widgets.dart';

/// Day-end reconciliation screen.
///
/// Shows expected physical cash (calculated server-side from today's
/// physical_cash transactions), lets the owner input the counted drawer
/// cash, then submits — server computes the discrepancy atomically.
class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() =>
      _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualCashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreview();
    });
  }

  @override
  void dispose() {
    _actualCashCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    await ref.read(closingProvider.notifier).loadPreview(date: _selectedDate);
    final preview = ref.read(closingProvider).preview;
    if (preview != null && mounted) {
      _actualCashCtrl.text = preview.actualCash.toStringAsFixed(2);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadPreview();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(closingProvider.notifier).submit(
          date: _selectedDate,
          actualCash: num.parse(_actualCashCtrl.text.trim()),
          note: _noteCtrl.text.trim().isEmpty
              ? null
              : _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      _showResult();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ref.read(closingProvider).error ?? 'Failed to submit closing'),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showResult() {
    final closing = ref.read(closingProvider).preview;
    if (closing == null) return;
    final hasMismatch = closing.hasMismatch;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (hasMismatch ? AppTheme.warning : AppTheme.success)
                      .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasMismatch ? Icons.warning : Icons.check_circle,
                  color: hasMismatch ? AppTheme.warning : AppTheme.success,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasMismatch ? 'Cash Mismatch Detected' : 'Closing Submitted',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _ResultRow('Expected Cash',
                  Formatters.currency(closing.expectedCash)),
              _ResultRow('Counted Cash',
                  Formatters.currency(closing.actualCash)),
              _ResultRow(
                'Discrepancy',
                Formatters.currency(closing.discrepancy),
                color: hasMismatch ? AppTheme.warning : AppTheme.success,
              ),
              _ResultRow("Today's Profit",
                  Formatters.currency(closing.totalProfit),
                  color: AppTheme.success),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                icon: Icons.check,
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/closing/history');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(closingProvider);
    final preview = state.preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Closing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/closing/history'),
            tooltip: 'History',
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading && preview == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date picker
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today,
                            color: AppTheme.primary),
                        title: Text(
                          Formatters.date(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text('Tap to change date'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Expected cash summary
                    if (preview != null) ...[
                      _SummaryCard(
                        title: 'System Calculated',
                        rows: [
                          _SummaryRow(
                            'Expected Physical Cash',
                            Formatters.currency(preview.expectedCash),
                            AppTheme.success,
                          ),
                          _SummaryRow(
                            "Today's Profit (Commission)",
                            Formatters.currency(preview.totalProfit),
                            AppTheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Counted cash input
                    Text('Count the cash in your drawer',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                    const SizedBox(height: 8),
                    AppTextField(
                      label: 'Actual Counted Cash',
                      controller: _actualCashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      prefixIcon: Icons.payments,
                      validator: Validators.amount,
                    ),
                    const SizedBox(height: 14),

                    AppTextField(
                      label: 'Note (optional)',
                      controller: _noteCtrl,
                      maxLines: 2,
                      prefixIcon: Icons.notes,
                      hint: 'e.g., "500 tk missing — likely wrong change given"',
                    ),
                    const SizedBox(height: 24),

                    PrimaryButton(
                      label: 'Submit Closing',
                      icon: Icons.check_circle,
                      loading: state.submitting,
                      onPressed: _submit,
                    ),

                    if (preview != null && preview.hasMismatch) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppTheme.warning, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A mismatch will be flagged. You can mark it '
                                'resolved later once the cause is identified.',
                                style: TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows});
  final String title;
  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.label, style: const TextStyle(fontSize: 13)),
                      Text(
                        r.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: r.color,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow {
  final String label;
  final String value;
  final Color color;
  const _SummaryRow(this.label, this.value, this.color);
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
