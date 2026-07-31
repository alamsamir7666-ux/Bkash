import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../core/config/app_config.dart';

/// Central Dio instance configured with the backend base URL and an
/// interceptor that attaches the Firebase ID token to every request.
///
/// The token is obtained fresh from FirebaseAuth on each request —
/// Firebase handles caching/refresh internally, so this is cheap.
///
/// Errors are normalised into [ApiException] so the UI layer never has to
/// deal with raw Dio error types.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
        maxWidth: 120,
      ),
    );
  }

  dio.interceptors.add(FirebaseAuthInterceptor());
  return dio;
});

/// Injects the current Firebase user's ID token into every outgoing
/// request. If the user is not signed in, the request goes out without
/// an Authorization header (the backend will return 401 if auth is required).
class FirebaseAuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // getIdToken(forceRefresh: false) returns a cached token if still valid,
      // or fetches a fresh one automatically if expired.
      final token = await user.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token might be stale or the user was deleted server-side.
      // Sign out so the UI returns to the login screen.
      await FirebaseAuth.instance.signOut();
    }
    handler.next(err);
  }
}

/// Normalised API error consumed by Riverpod providers and the UI layer.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.payload,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  factory ApiException.fromDio(DioException err) {
    final data = err.response?.data;
    String message = err.message ?? 'Network error';
    if (data is Map<String, dynamic>) {
      message = data['message'] as String? ?? data['error'] as String? ?? message;
    }
    return ApiException(
      message: message,
      statusCode: err.response?.statusCode,
      payload: data is Map<String, dynamic> ? data : null,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
