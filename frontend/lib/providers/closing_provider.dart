import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_closing_model.dart';
import '../services/closing_service.dart';

class ClosingState {
  const ClosingState({
    this.preview,
    this.history = const [],
    this.loading = false,
    this.submitting = false,
    this.error,
  });

  final DailyClosingModel? preview;
  final List<DailyClosingModel> history;
  final bool loading;
  final bool submitting;
  final String? error;

  ClosingState copyWith({
    DailyClosingModel? preview,
    List<DailyClosingModel>? history,
    bool? loading,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return ClosingState(
      preview: preview ?? this.preview,
      history: history ?? this.history,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ClosingNotifier extends StateNotifier<ClosingState> {
  ClosingNotifier(this.ref) : super(const ClosingState());
  final Ref ref;

  Future<void> loadPreview({DateTime? date}) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(closingServiceProvider);
      final preview = await service.preview(date: date);
      state = state.copyWith(preview: preview, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> submit({
    required DateTime date,
    required num actualCash,
    String? note,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final service = ref.read(closingServiceProvider);
      final closing = await service.submit(
        date: date,
        actualCash: actualCash,
        note: note,
      );
      state = state.copyWith(
        preview: closing,
        submitting: false,
        history: [closing, ...state.history],
      );
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = ref.read(closingServiceProvider);
      final history = await service.history();
      state = state.copyWith(history: history, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<bool> resolve(String id) async {
    try {
      final service = ref.read(closingServiceProvider);
      final updated = await service.resolve(id);
      state = state.copyWith(
        history: state.history
            .map((c) => c.id == id ? updated : c)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final closingProvider =
    StateNotifierProvider<ClosingNotifier, ClosingState>((ref) {
  return ClosingNotifier(ref);
});
