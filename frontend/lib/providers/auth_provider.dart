import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Tracks the current authentication state across the app.
///
/// `AuthState.loading` is true during the initial session-restore check
/// on app launch. Subsequent login/register calls use `loadingAction`
/// so the rest of the UI does not flicker.
class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.loadingAction = false,
    this.error,
    this.requiresOnboarding = false,
  });

  final UserModel? user;
  final bool loading;
  final bool loadingAction;
  final String? error;
  final bool requiresOnboarding;

  bool get isAuthenticated => user != null && !requiresOnboarding;

  AuthState copyWith({
    UserModel? user,
    bool? loading,
    bool? loadingAction,
    String? error,
    bool? requiresOnboarding,
    bool clearError = false,
    bool clearRequiresOnboarding = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      loadingAction: loadingAction ?? this.loadingAction,
      error: clearError ? null : (error ?? this.error),
      requiresOnboarding: clearRequiresOnboarding
          ? false
          : (requiresOnboarding ?? this.requiresOnboarding),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.ref) : super(const AuthState(loading: true)) {
    _init();
  }

  final Ref ref;
  StreamSubscription<User?>? _firebaseSub;

  /// Subscribes to Firebase auth state changes. On sign-in, fetches the
  /// user's profile from the backend. On sign-out, clears state.
  Future<void> _init() async {
    final service = ref.read(authServiceProvider);

    // If Firebase has a current user on app launch, fetch their profile.
    // Otherwise, we're done loading.
    final firebaseUser = service.currentFirebaseUser;
    if (firebaseUser == null) {
      state = const AuthState(loading: false);
    } else {
      await _loadProfile();
    }

    // Listen for future auth state changes.
    _firebaseSub = service.authStateChanges.listen((user) async {
      if (user == null) {
        state = const AuthState(loading: false);
      } else {
        // Don't set loading=true — we already have a UI up. Just refresh
        // the profile in the background.
        await _loadProfile();
      }
    });
  }

  Future<void> _loadProfile() async {
    final service = ref.read(authServiceProvider);
    try {
      final user = await service.me();
      state = AuthState(user: user, loading: false);
    } on OnboardingRequiredException {
      state = AuthState(
        loading: false,
        requiresOnboarding: true,
      );
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loadingAction: true, clearError: true, clearRequiresOnboarding: true);
    try {
      final service = ref.read(authServiceProvider);
      final user = await service.login(email: email, password: password);
      state = AuthState(user: user);
      return true;
    } on OnboardingRequiredException {
      state = state.copyWith(
        loadingAction: false,
        requiresOnboarding: true,
      );
      return false;
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
    state = state.copyWith(loadingAction: true, clearError: true, clearRequiresOnboarding: true);
    try {
      final service = ref.read(authServiceProvider);
      final user = await service.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(loadingAction: false, error: e.toString());
      return false;
    }
  }

  /// Completes the onboarding flow for a user who signed in via Firebase
  /// but hasn't yet created a User row in the backend.
  Future<bool> completeOnboarding({required String name, String? phone}) async {
    state = state.copyWith(loadingAction: true, clearError: true);
    try {
      final service = ref.read(authServiceProvider);
      final user = await service.onboard(name: name, phone: phone);
      state = AuthState(user: user);
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

  @override
  void dispose() {
    _firebaseSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
