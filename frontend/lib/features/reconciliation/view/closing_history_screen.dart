import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/daily_closing_model.dart';
import '../../../providers/closing_provider.dart';

class ClosingHistoryScreen extends ConsumerStatefulWidget {
  const ClosingHistoryScreen({super.key});

  @override
  ConsumerState<ClosingHistoryScreen> createState() =>
      _ClosingHistoryScreenState();
}

class _ClosingHistoryScreenState extends ConsumerState<ClosingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(closingProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(closingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Closing History')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(closingProvider.notifier).loadHistory(),
          child: state.loading && state.history.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.history.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        _EmptyState(),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final c = state.history[i];
                        return _ClosingCard(
                          closing: c,
                          onResolve: () =>
                              ref.read(closingProvider.notifier).resolve(c.id),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({required this.closing, required this.onResolve});
  final DailyClosingModel closing;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final hasMismatch = closing.hasMismatch;
    final accent = hasMismatch ? AppTheme.warning : AppTheme.success;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasMismatch ? Icons.warning_amber : Icons.check_circle,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Formatters.date(closing.date),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Profit ${Formatters.currency(closing.totalProfit)}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasMismatch && !closing.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (closing.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'RESOLVED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            _row('Expected Cash', Formatters.currency(closing.expectedCash)),
            _row('Counted Cash', Formatters.currency(closing.actualCash)),
            _row(
              'Discrepancy',
              Formatters.currency(closing.discrepancy),
              color: hasMismatch ? AppTheme.warning : AppTheme.success,
            ),
            if (hasMismatch && !closing.isResolved) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark as Resolved'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              )),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color ?? AppTheme.textPrimary,
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
            const Icon(Icons.nightlight_outlined,
                size: 56, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            const Text(
              'No closing records yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Submit your first daily closing from the Closing tab.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
