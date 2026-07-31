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

  /// Guard that prevents the authStateChanges listener from racing with
  /// an in-flight register() / completeOnboarding() call.
  ///
  /// When register() calls createUserWithEmailAndPassword(), Firebase
  /// fires authStateChanges synchronously. Without this guard, the
  /// listener would call _loadProfile() → /auth/me → 404 → set
  /// requiresOnboarding=true → router redirects to /onboarding — BEFORE
  /// register() has had a chance to call /auth/onboard. The user would
  /// see "nothing happens" because the in-flight onboard call would
  /// complete and overwrite state, but the router may have already
  /// flickered.
  bool _isMutating = false;

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
        // Sign-out — clear everything.
        state = const AuthState(loading: false);
      } else {
        // Sign-in event. If a register()/completeOnboarding() call is in
        // flight, let IT own the state transition — the listener would
        // otherwise race ahead and call /auth/me before /auth/onboard
        // has finished, getting a 404 and wrongly showing onboarding.
        if (_isMutating) return;
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
    state = state.copyWith(
      loadingAction: true,
      clearError: true,
      clearRequiresOnboarding: true,
    );
    _isMutating = true;
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
        error: _friendlyError(e),
      );
      return false;
    } finally {
      _isMutating = false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(
      loadingAction: true,
      clearError: true,
      clearRequiresOnboarding: true,
    );
    _isMutating = true;
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
      state = state.copyWith(
        loadingAction: false,
        error: _friendlyError(e),
      );
      return false;
    } finally {
      _isMutating = false;
    }
  }

  /// Completes the onboarding flow for a user who signed in via Firebase
  /// but hasn't yet created a User row in the backend.
  Future<bool> completeOnboarding({required String name, String? phone}) async {
    state = state.copyWith(loadingAction: true, clearError: true);
    _isMutating = true;
    try {
      final service = ref.read(authServiceProvider);
      final user = await service.onboard(name: name, phone: phone);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        loadingAction: false,
        error: _friendlyError(e),
      );
      return false;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Converts raw FirebaseAuth / Dio / ApiException errors into something
  /// a Bangladeshi shop owner can actually understand. Without this, the
  /// user sees messages like "[firebase_auth/invalid-credential] ..." which
  /// looks like the app is broken.
  String _friendlyError(Object e) {
    final raw = e.toString();

    // FirebaseAuth error codes look like:
    //   [firebase_auth/email-already-in-use] The email address is already in use by another account.
    //   [firebase_auth/invalid-credential] The supplied auth credential is incorrect.
    //   [firebase_auth/network-request-failed] A network error ...
    final codeMatch = RegExp(r'\[firebase_auth/([a-z\-]+)\]').firstMatch(raw);
    if (codeMatch != null) {
      switch (codeMatch.group(1)) {
        case 'email-already-in-use':
          return 'This email is already registered. Try signing in instead.';
        case 'invalid-email':
          return 'That email address looks malformed.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters with letters and numbers.';
        case 'invalid-credential':
        case 'wrong-password':
          return 'Email or password is incorrect.';
        case 'user-not-found':
          return 'No account found with this email. Register first.';
        case 'user-disabled':
          return 'This account has been disabled. Contact support.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a minute and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your Wi-Fi or mobile data.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled in Firebase. Contact support.';
        default:
          // Fall through to generic message.
          break;
      }
    }

    // Dio network errors.
    if (raw.contains('SocketException') ||
        raw.contains('HandshakeException') ||
        raw.contains('Failed host lookup')) {
      return 'Cannot reach the server. Check your internet connection.';
    }
    if (raw.contains('Connection timed out') ||
        raw.contains('TimeoutException') ||
        raw.contains('Connecting timed out')) {
      return 'The server took too long to respond. Try again.';
    }

    // ApiException already has a clean message — strip the prefix.
    if (raw.startsWith('ApiException(')) {
      // "ApiException(409): Email already registered" → "Email already registered"
      final idx = raw.indexOf('): ');
      if (idx != -1) return raw.substring(idx + 3);
    }

    // Last resort — return the raw message but trim it.
    return raw.length > 200 ? '${raw.substring(0, 200)}...' : raw;
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
