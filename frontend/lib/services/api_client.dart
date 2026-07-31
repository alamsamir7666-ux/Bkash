import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';

/// Central Dio instance configured with the backend base URL and an
/// interceptor that attaches the JWT auth token from secure storage.
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

  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

/// Injects the cached JWT into every outgoing request and handles
/// 401 responses by clearing the session (forcing a re-login).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.ref);
  final Ref ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConfig.accessTokenKey);
    if (token != null && token.isNotEmpty) {
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
      const storage = FlutterSecureStorage();
      await storage.delete(key: AppConfig.accessTokenKey);
      await storage.delete(key: AppConfig.userIdKey);
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
