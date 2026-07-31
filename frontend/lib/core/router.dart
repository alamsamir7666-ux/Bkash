import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/view/login_screen.dart';
import '../features/auth/view/onboarding_screen.dart';
import '../features/auth/view/register_screen.dart';
import '../features/dashboard/view/dashboard_screen.dart';
import '../features/reconciliation/view/closing_history_screen.dart';
import '../features/reconciliation/view/daily_closing_screen.dart';
import '../features/transactions/view/add_transaction_screen.dart';
import '../features/transactions/view/transaction_list_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final isAuthenticated = auth.isAuthenticated;
      final requiresOnboarding = auth.requiresOnboarding;
      final isLoading = auth.loading;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/onboarding';

      if (isLoading) return null;

      // User is signed in via Firebase but hasn't onboarded yet.
      // Force them to the onboarding screen.
      if (requiresOnboarding && state.matchedLocation != '/onboarding') {
        return '/onboarding';
      }
      // Once onboarded, leave the onboarding screen.
      if (!requiresOnboarding && isAuthenticated && state.matchedLocation == '/onboarding') {
        return '/';
      }

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute && !requiresOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _Shell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionListScreen(),
          ),
          GoRoute(
            path: '/transactions/add',
            builder: (context, state) => const AddTransactionScreen(),
          ),
          GoRoute(
            path: '/closing',
            builder: (context, state) => const DailyClosingScreen(),
          ),
          GoRoute(
            path: '/closing/history',
            builder: (context, state) => const ClosingHistoryScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.matchedLocation}')),
    ),
  );
});

/// Bridges the [AuthState] changes into a [Listenable] so GoRouter can
/// re-evaluate redirects whenever auth changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authProvider, (_, __) => notifyListeners());
  }
  // ignore: unused_field
  late final ProviderSubscription _sub;
}

/// Bottom-nav shell that hosts the 3 top-level destinations.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int index = 0;
    if (location.startsWith('/transactions')) index = 1;
    if (location.startsWith('/closing')) index = 2;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/transactions');
              break;
            case 2:
              context.go('/closing');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Ledger',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.nightlight_outlined),
            activeIcon: Icon(Icons.nightlight),
            label: 'Closing',
          ),
        ],
      ),
    );
  }
}
