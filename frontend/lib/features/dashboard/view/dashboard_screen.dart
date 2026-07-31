import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/closing_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/balance_card.dart';
import '../widgets/profit_summary.dart';
import '../widgets/transaction_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to next frame so providers are mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accountsProvider.notifier).refresh();
      ref.read(transactionsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final accounts = ref.watch(accountsProvider);
    final trx = ref.watch(transactionsProvider);
    final closing = ref.watch(closingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${auth.user?.name.split(' ').first ?? 'Shop Owner'}',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              Formatters.date(DateTime.now()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') ref.read(authProvider.notifier).logout();
            },
            icon: const Icon(Icons.account_circle),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(accountsProvider.notifier).refresh(),
            ref.read(transactionsProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            // Total balance hero
            _TotalBalanceCard(
              total: accounts.totalBalance,
              todayProfit: trx.summary?.todayProfit ?? 0,
            ),
            const SizedBox(height: 16),

            // Accounts carousel
            if (accounts.loading && accounts.accounts.isEmpty)
              const _AccountsSkeleton()
            else
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => BalanceCard(
                    account: accounts.accounts[i],
                    onTap: () => context.push('/transactions'),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Quick actions
            _QuickActions(),
            const SizedBox(height: 16),

            // Today's mismatch banner (if any)
            if (closing.preview?.hasMismatch == true)
              _MismatchBanner(
                discrepancy: closing.preview!.discrepancy,
              ),

            // Profit summary
            if (trx.summary != null) ...[
              ProfitSummary(summary: trx.summary!),
              const SizedBox(height: 16),
            ],

            // Recent transactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: const Text('View All'),
                ),
              ],
            ),
            if (trx.loading && trx.items.isEmpty)
              const _ListSkeleton()
            else if (trx.items.isEmpty)
              const _EmptyState()
            else
              Card(
                child: Column(
                  children: [
                    for (final t in trx.items.take(5))
                      TransactionTile(
                        transaction: t,
                        onTap: () => context.push('/transactions'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/transactions/add');
          ref.read(accountsProvider.notifier).refresh();
          ref.read(transactionsProvider.notifier).refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Transaction'),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.total, required this.todayProfit});

  final num total;
  final num todayProfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Holdings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.currency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '+ ${Formatters.currency(todayProfit)} today',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_balance,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(Icons.south_west, 'Cash In', AppTheme.success),
      _Action(Icons.north_east, 'Cash Out', AppTheme.danger),
      _Action(Icons.send, 'Send Money', AppTheme.secondary),
      _Action(Icons.savings, 'Add Capital', AppTheme.primary),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final a in actions) ...[
              Expanded(child: _actionItem(context, a)),
              if (a != actions.last) Container(width: 1, height: 40, color: AppTheme.divider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionItem(BuildContext context, _Action a) {
    return InkWell(
      onTap: () => context.push('/transactions/add'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: a.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(a.icon, color: a.color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            a.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final Color color;
  const _Action(this.icon, this.label, this.color);
}

class _MismatchBanner extends StatelessWidget {
  const _MismatchBanner({required this.discrepancy});
  final num discrepancy;

  @override
  Widget build(BuildContext context) {
    final isShort = discrepancy < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.12),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: AppTheme.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isShort ? 'Cash drawer is short' : 'Cash drawer has surplus',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${Formatters.currency(discrepancy.abs())} ${isShort ? "missing" : "extra"} from yesterday',
                  style: const TextStyle(fontSize: 11, color: AppTheme.warning),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/closing'),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 220,
          decoration: BoxDecoration(
            color: AppTheme.divider,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: List.generate(5, (_) => const ListTile(
          leading: CircleAvatar(backgroundColor: AppTheme.divider),
          title: SizedBox(
            height: 12,
            child: LinearProgressIndicator(backgroundColor: AppTheme.divider),
          ),
          subtitle: SizedBox(
            height: 10,
            child: LinearProgressIndicator(backgroundColor: AppTheme.divider),
          ),
        )),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 48, color: AppTheme.textSecondary),
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
              'Tap "New Transaction" to record your first entry.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
