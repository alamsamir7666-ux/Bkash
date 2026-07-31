import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import 'api_client.dart';

final transactionServiceProvider =
    Provider<TransactionService>((ref) => TransactionService(ref));

/// Writes + reads against the `transactions` table.
///
/// The backend atomically updates the source / target account balances
/// inside a Prisma transaction, so the UI never directly mutates balances.
class TransactionService {
  TransactionService(this.ref);
  final Ref ref;

  Dio get _dio => ref.read(dioProvider);

  Future<List<TransactionModel>> list({
    int limit = 50,
    int offset = 0,
    String? trxType,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final query = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (trxType != null) 'trx_type': trxType,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      };
      final res = await _dio.get(
        '/transactions',
        queryParameters: query,
      );
      final list = res.data['transactions'] as List<dynamic>;
      return list
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<TransactionModel> create({
    required String trxType,
    required num amount,
    num commission = 0,
    String? sourceAccountId,
    String? targetAccountId,
    String? customerPhone,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        '/transactions',
        data: {
          'trx_type': trxType,
          'amount': amount,
          'commission': commission,
          if (sourceAccountId != null) 'source_account': sourceAccountId,
          if (targetAccountId != null) 'target_account': targetAccountId,
          if (customerPhone != null) 'customer_phone': customerPhone,
          if (note != null) 'note': note,
        },
      );
      return TransactionModel.fromJson(
        res.data['transaction'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/transactions/$id');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Aggregate stats for the dashboard: today's profit, today's count,
  /// total volume, etc. Computed server-side to avoid pulling the entire
  /// ledger over the wire.
  Future<TransactionSummary> summary({DateTime? forDate}) async {
    try {
      final res = await _dio.get(
        '/transactions/summary',
        queryParameters: {
          if (forDate != null) 'date': forDate.toIso8601String(),
        },
      );
      return TransactionSummary.fromJson(
        res.data['summary'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Aggregated metrics returned by `/transactions/summary`.
class TransactionSummary {
  final num todayProfit;
  final num todayVolume;
  final int todayCount;
  final num weekProfit;
  final num monthProfit;

  const TransactionSummary({
    required this.todayProfit,
    required this.todayVolume,
    required this.todayCount,
    required this.weekProfit,
    required this.monthProfit,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      todayProfit: num.parse((json['today_profit'] ?? 0).toString()),
      todayVolume: num.parse((json['today_volume'] ?? 0).toString()),
      todayCount: (json['today_count'] ?? 0) as int,
      weekProfit: num.parse((json['week_profit'] ?? 0).toString()),
      monthProfit: num.parse((json['month_profit'] ?? 0).toString()),
    );
  }
}
