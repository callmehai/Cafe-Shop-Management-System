import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/report_models.dart';

/// Tính khoảng ngày từ preset 'today' | '7d' | '30d'.
({DateTime from, DateTime to}) rangeDates(String range) {
  final now = DateTime.now();
  final from = switch (range) {
    'today' => DateTime(now.year, now.month, now.day),
    '30d' => now.subtract(const Duration(days: 29)),
    _ => now.subtract(const Duration(days: 6)),
  };
  return (from: from, to: now);
}

class ReportsRepository {
  ReportsRepository(this._api);
  final ApiClient _api;

  Future<DashboardStats> dashboard() async {
    final res = await _api.dio.get('/reports/dashboard');
    return DashboardStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SalesReport> sales({String? from, String? to}) async {
    final res = await _api.dio.get('/reports/sales', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return SalesReport.fromJson(res.data as Map<String, dynamic>);
  }

  // UC21: lấy CSV báo cáo (trả về dạng text thuần).
  Future<String> exportCsv(String range) async {
    final d = rangeDates(range);
    final res = await _api.dio.get(
      '/reports/sales/export',
      queryParameters: {'from': d.from.toIso8601String(), 'to': d.to.toIso8601String()},
      options: Options(responseType: ResponseType.plain),
    );
    return res.data.toString();
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

/// Số liệu dashboard (home theo role).
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>(
  (ref) => ref.watch(reportsRepositoryProvider).dashboard(),
);

/// Báo cáo doanh thu theo preset khoảng ngày: 'today' | '7d' | '30d'.
final salesReportProvider = FutureProvider.autoDispose.family<SalesReport, String>((ref, range) {
  final now = DateTime.now();
  late DateTime from;
  switch (range) {
    case 'today':
      from = DateTime(now.year, now.month, now.day);
      break;
    case '30d':
      from = now.subtract(const Duration(days: 29));
      break;
    case '7d':
    default:
      from = now.subtract(const Duration(days: 6));
  }
  return ref.watch(reportsRepositoryProvider).sales(
        from: from.toIso8601String(),
        to: now.toIso8601String(),
      );
});
