import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_model.dart';
import '../services/account_service.dart';

class AccountsState {
  const AccountsState({
    this.accounts = const [],
    this.loading = false,
    this.error,
  });

  final List<AccountModel> accounts;
  final bool loading;
  final String? error;

  /// Total holdings across all accounts.
  num get totalBalance =>
      accounts.fold(0, (sum, a) => sum + a.balance);

  /// Convenience getters for the three conventional account types.
  AccountModel? get agentBkash =>
      accounts.where((a) => a.accountType == 'agent_bKash').firstOrNull;
  AccountModel? get personalBkash =>
      accounts.where((a) => a.accountType == 'personal_bKash').firstOrNull;
  AccountModel? get physicalCash =>
      accounts.where((a) => a.accountType == 'physical_cash').firstOrNull;

  AccountsState copyWith({
    List<AccountModel>? accounts,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AccountsState(
      accounts: accounts ?? this.accounts,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AccountsNotifier extends StateNotifier<AccountsState> {
  AccountsNotifier(this.ref) : super(const AccountsState());
  final Ref ref;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(accountServiceProvider);
      final accounts = await service.list();
      state = AccountsState(accounts: accounts, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createAccount({
    required String accountType,
    num initialBalance = 0,
  }) async {
    try {
      final service = ref.read(accountServiceProvider);
      final account = await service.create(
        accountType: accountType,
        initialBalance: initialBalance,
      );
      state = state.copyWith(accounts: [...state.accounts, account]);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, AccountsState>((ref) {
  return AccountsNotifier(ref);
});
