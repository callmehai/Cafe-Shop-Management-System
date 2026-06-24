import '../../../core/utils/format.dart';

class TopProduct {
  const TopProduct({required this.name, required this.qty, required this.revenue});
  final String name;
  final int qty;
  final double revenue;

  factory TopProduct.fromJson(Map<String, dynamic> json) => TopProduct(
        name: json['name'] as String? ?? '',
        qty: json['qty'] as int? ?? 0,
        revenue: parseAmount(json['revenue']),
      );

  String get revenueLabel => formatVnd(revenue);
}

class SalesReport {
  const SalesReport({
    required this.totalRevenue,
    required this.orderCount,
    required this.avgTicket,
    required this.topProducts,
  });

  final double totalRevenue;
  final int orderCount;
  final double avgTicket;
  final List<TopProduct> topProducts;

  factory SalesReport.fromJson(Map<String, dynamic> json) => SalesReport(
        totalRevenue: parseAmount(json['totalRevenue']),
        orderCount: json['orderCount'] as int? ?? 0,
        avgTicket: parseAmount(json['avgTicket']),
        topProducts: (json['topProducts'] as List? ?? [])
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardStats {
  const DashboardStats({
    required this.revenueToday,
    required this.ordersToday,
    required this.openOrders,
    required this.tablesFree,
    required this.tablesTotal,
    required this.lowStockCount,
    required this.lowStock,
    required this.userCount,
    required this.activeUsers,
  });

  final double revenueToday;
  final int ordersToday;
  final int openOrders;
  final int tablesFree;
  final int tablesTotal;
  final int lowStockCount;
  final List<String> lowStock;
  final int userCount;
  final int activeUsers;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        revenueToday: parseAmount(json['revenueToday']),
        ordersToday: json['ordersToday'] as int? ?? 0,
        openOrders: json['openOrders'] as int? ?? 0,
        tablesFree: json['tablesFree'] as int? ?? 0,
        tablesTotal: json['tablesTotal'] as int? ?? 0,
        lowStockCount: json['lowStockCount'] as int? ?? 0,
        lowStock: (json['lowStock'] as List? ?? []).map((e) => e.toString()).toList(),
        userCount: json['userCount'] as int? ?? 0,
        activeUsers: json['activeUsers'] as int? ?? 0,
      );

  String get revenueTodayLabel => formatVnd(revenueToday);
}
