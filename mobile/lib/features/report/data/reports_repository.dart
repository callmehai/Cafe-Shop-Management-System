import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/report_models.dart';

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
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

/// Số liệu dashboard (home theo role).
final dashboardStatsProvider = FutureProvider<DashboardStats>(
  (ref) => ref.watch(reportsRepositoryProvider).dashboard(),
);

/// Báo cáo doanh thu theo preset khoảng ngày: 'today' | '7d' | '30d'.
final salesReportProvider = FutureProvider.family<SalesReport, String>((ref, range) {
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
