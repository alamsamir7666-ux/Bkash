import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_model.dart';
import 'api_client.dart';

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(ref);
});

/// CRUD + balance operations for the `accounts` table.
///
/// On first login the backend auto-creates the three default account
/// pockets (agent_bKash, personal_bKash, physical_cash), so the UI can
/// always assume at least three accounts exist per shop.
class AccountService {
  AccountService(this.ref);
  final Ref ref;

  Dio get _dio => ref.read(dioProvider);

  Future<List<AccountModel>> list() async {
    try {
      final res = await _dio.get('/accounts');
      final list = res.data['accounts'] as List<dynamic>;
      return list
          .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AccountModel> create({
    required String accountType,
    num initialBalance = 0,
  }) async {
    try {
      final res = await _dio.post(
        '/accounts',
        data: {
          'account_type': accountType,
          'initial_balance': initialBalance,
        },
      );
      return AccountModel.fromJson(res.data['account'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AccountModel> updateBalance({
    required String accountId,
    required num newBalance,
  }) async {
    try {
      final res = await _dio.patch(
        '/accounts/$accountId',
        data: {'balance': newBalance},
      );
      return AccountModel.fromJson(res.data['account'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
