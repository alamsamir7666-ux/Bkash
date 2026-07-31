import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/config/app_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

/// Handles login / register / logout against the Node.js backend and
/// persists the issued JWT in secure storage.
///
/// The backend is responsible for hashing passwords (bcrypt) and signing
/// the JWT; this class only orchestrates HTTP + storage.
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  Dio get _dio => ref.read(dioProvider);

  Future<({UserModel user, String token})> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return _persist(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<({UserModel user, String token})> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return _persist(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserModel> me() async {
    try {
      final res = await _dio.get('/auth/me');
      return UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: AppConfig.accessTokenKey);
    await storage.delete(key: AppConfig.userIdKey);
  }

  Future<String?> get cachedToken async {
    const storage = FlutterSecureStorage();
    return storage.read(key: AppConfig.accessTokenKey);
  }

  ({UserModel user, String token}) _persist(Map<String, dynamic> body) {
    final token = body['token'] as String;
    final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);

    const storage = FlutterSecureStorage();
    storage.write(key: AppConfig.accessTokenKey, value: token);
    storage.write(key: AppConfig.userIdKey, value: user.id);
    return (user: user, token: token);
  }
}
