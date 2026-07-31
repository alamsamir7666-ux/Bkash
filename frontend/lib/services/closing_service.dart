import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_closing_model.dart';
import 'api_client.dart';

final closingServiceProvider =
    Provider<ClosingService>((ref) => ClosingService(ref));

/// Day-end reconciliation API. The backend computes `expected_cash`
/// (sum of physical_cash transactions for the day) and `discrepancy`
/// when a closing is created; the UI only supplies `actual_cash`.
class ClosingService {
  ClosingService(this.ref);
  final Ref ref;

  Dio get _dio => ref.read(dioProvider);

  /// Previews the expected cash + profit for the given date without
  /// committing a closing record. Used by the closing screen so the
  /// owner can see what the system thinks *before* counting the drawer.
  Future<DailyClosingModel> preview({DateTime? date}) async {
    try {
      final res = await _dio.get(
        '/closings/preview',
        queryParameters: {
          if (date != null) 'date': _dateKey(date),
        },
      );
      return DailyClosingModel.fromJson(
        res.data['closing'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DailyClosingModel> submit({
    required DateTime date,
    required num actualCash,
    String? note,
  }) async {
    try {
      final res = await _dio.post(
        '/closings',
        data: {
          'date': _dateKey(date),
          'actual_cash': actualCash,
          if (note != null) 'note': note,
        },
      );
      return DailyClosingModel.fromJson(
        res.data['closing'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<DailyClosingModel>> history({int limit = 30}) async {
    try {
      final res = await _dio.get(
        '/closings',
        queryParameters: {'limit': limit},
      );
      final list = res.data['closings'] as List<dynamic>;
      return list
          .map((e) => DailyClosingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<DailyClosingModel> resolve(String id) async {
    try {
      final res = await _dio.patch('/closings/$id/resolve');
      return DailyClosingModel.fromJson(
        res.data['closing'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
