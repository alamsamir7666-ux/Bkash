import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'accounts_provider.dart';

class TransactionsState {
  const TransactionsState({
    this.items = const [],
    this.summary,
    this.loading = false,
    this.submitting = false,
    this.error,
  });

  final List<TransactionModel> items;
  final TransactionSummary? summary;
  final bool loading;
  final bool submitting;
  final String? error;

  TransactionsState copyWith({
    List<TransactionModel>? items,
    TransactionSummary? summary,
    bool? loading,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return TransactionsState(
      items: items ?? this.items,
      summary: summary ?? this.summary,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  TransactionsNotifier(this.ref) : super(const TransactionsState());
  final Ref ref;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(transactionServiceProvider);
      final results = await Future.wait([
        service.list(limit: 100),
        service.summary(),
      ]);
      state = TransactionsState(
        items: results[0] as List<TransactionModel>,
        summary: results[1] as TransactionSummary,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> create({
    required String trxType,
    required num amount,
    num commission = 0,
    String? sourceAccountId,
    String? targetAccountId,
    String? customerPhone,
    String? note,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final service = ref.read(transactionServiceProvider);
      final trx = await service.create(
        trxType: trxType,
        amount: amount,
        commission: commission,
        sourceAccountId: sourceAccountId,
        targetAccountId: targetAccountId,
        customerPhone: customerPhone,
        note: note,
      );
      state = state.copyWith(
        items: [trx, ...state.items],
        submitting: false,
      );
      // Refresh summary + accounts in the background.
      ref.read(accountsProvider.notifier).refresh();
      ref.read(transactionsProvider.notifier).refreshSummary();
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshSummary() async {
    try {
      final service = ref.read(transactionServiceProvider);
      final summary = await service.summary();
      state = state.copyWith(summary: summary);
    } catch (_) {
      // Silent failure — summary is non-critical.
    }
  }

  Future<bool> delete(String id) async {
    try {
      final service = ref.read(transactionServiceProvider);
      await service.delete(id);
      state = state.copyWith(
        items: state.items.where((t) => t.id != id).toList(),
      );
      ref.read(accountsProvider.notifier).refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  return TransactionsNotifier(ref);
});
