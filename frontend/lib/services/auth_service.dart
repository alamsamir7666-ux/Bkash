import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import 'api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

/// Handles authentication via Firebase Auth (email/password) and
/// bridges to the Node.js backend for user profile data.
///
/// Flow:
///   - login(email, password):
///       1. FirebaseAuth.signInWithEmailAndPassword() — Firebase owns identity
///       2. backend GET /auth/me — fetch the user's business profile
///       3. If /me returns 404, the user hasn't onboarded yet; throw
///          [OnboardingRequiredException] so the UI can route them to
///          the onboarding screen.
///
///   - register(name, email, password, phone):
///       1. FirebaseAuth.createUserWithEmailAndPassword() — creates Firebase user
///       2. Get the user's fresh ID token
///       3. backend POST /auth/onboard { name, phone } — creates the User row
///          + 3 default account pockets (agent_bKash, personal_bKash, physical_cash)
///
///   - logout(): FirebaseAuth.signOut() — the backend is stateless.
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  Dio get _dio => ref.read(dioProvider);
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Signs in with Firebase, then fetches the user's profile from the backend.
  ///
  /// Throws [OnboardingRequiredException] if the user exists in Firebase but
  /// hasn't completed onboarding (POST /auth/onboard) yet.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // 1. Firebase sign-in
    await _auth.signInWithEmailAndPassword(email: email, password: password);

    // 2. Fetch profile from backend
    try {
      final res = await _dio.get('/auth/me');
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw OnboardingRequiredException();
      }
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Creates a Firebase user, then onboards them on the backend (creates
  /// the User row + 3 default account pockets).
  ///
  /// If [createUserWithEmailAndPassword] succeeds but the backend /onboard
  /// call fails, we deliberately do NOT sign out — that would discard the
  /// freshly-created Firebase user. Instead, the next time the user opens
  /// the app, /auth/me will 404 and they'll be routed to the onboarding
  /// screen to retry just the backend step.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    // 1. Create Firebase user (auto-signs in).
    // NOTE: FirebaseAuthException is thrown for email-already-in-use, weak
    // password, invalid email, etc. The caller (AuthNotifier._friendlyError)
    // translates these into human-readable messages.
    await _auth.createUserWithEmailAndPassword(email: email, password: password);

    // 2. Onboard on backend — AuthInterceptor will attach the Firebase ID token.
    try {
      final res = await _dio.post('/auth/onboard', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Already onboarded (e.g. previous call succeeded but client timed
        // out before receiving the response). Just fetch the profile.
        return me();
      }
      // For any other backend error, rethrow so the UI can show it. The
      // user is still Firebase-signed-in; on next app launch, /auth/me
      // will 404 and route them to the onboarding screen to retry.
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Fetches the current user's profile from the backend. Throws
  /// [OnboardingRequiredException] if the user is signed in via Firebase
  /// but hasn't onboarded yet.
  Future<UserModel> me() async {
    try {
      final res = await _dio.get('/auth/me');
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw OnboardingRequiredException();
      }
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Completes onboarding for a user who is already signed in via Firebase
  /// (e.g. they signed in with login() and got OnboardingRequiredException).
  /// Calls POST /auth/onboard to create the User row + 3 default accounts.
  Future<UserModel> onboard({
    required String name,
    String? phone,
  }) async {
    try {
      final res = await _dio.post('/auth/onboard', data: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Already onboarded — just fetch the profile.
        return me();
      }
      rethrow;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Returns the current Firebase user (or null if signed out).
  User? get currentFirebaseUser => _auth.currentUser;

  /// Stream of Firebase auth state changes. Used by AuthNotifier to
  /// reactively rebuild the UI on sign-in / sign-out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

/// Thrown when the user exists in Firebase but hasn't onboarded yet
/// (no User row in the backend DB). The UI should catch this and
/// navigate to the onboarding screen.
class OnboardingRequiredException implements Exception {
  final String message = 'Onboarding required — please complete your profile';
  OnboardingRequiredException();
  @override
  String toString() => message;
}
