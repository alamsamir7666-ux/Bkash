import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Tracks the current authentication state across the app.
///
/// `AuthState.loading` is true only during the initial session-restore
/// check on app launch; subsequent login/register calls use the
/// `loadingAction` flag so the rest of the UI does not flicker.
class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.loadingAction = false,
    this.error,
  });

  final UserModel? user;
  final bool loading;
  final bool loadingAction;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    bool? loadingAction,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      loadingAction: loadingAction ?? this.loadingAction,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState(loading: true)) {
    _restore();
  }

  final Ref ref;

  Future<void> _restore() async {
    final service = ref.read(authServiceProvider);
    final token = await service.cachedToken;
    if (token == null) {
      state = const AuthState(loading: false);
      return;
    }
    try {
      final user = await service.me();
      state = AuthState(user: user, loading: false);
    } catch (_) {
      state = const AuthState(loading: false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loadingAction: true, clearError: true);
    try {
      final service = ref.read(authServiceProvider);
      final result = await service.login(email: email, password: password);
      state = AuthState(user: result.user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loadingAction: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(loadingAction: true, clearError: true);
    try {
      final service = ref.read(authServiceProvider);
      final result = await service.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      state = AuthState(user: result.user);
      return true;
    } catch (e) {
      state = state.copyWith(loadingAction: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
