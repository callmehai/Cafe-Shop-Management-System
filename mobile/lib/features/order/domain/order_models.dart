import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';

enum OrderStatus {
  open,
  paid,
  cancelled,
  unknown;

  static OrderStatus fromApi(String raw) => switch (raw.toUpperCase()) {
        'OPEN' => OrderStatus.open,
        'PAID' => OrderStatus.paid,
        'CANCELLED' => OrderStatus.cancelled,
        _ => OrderStatus.unknown,
      };

  String get label => switch (this) {
        OrderStatus.open => 'Open',
        OrderStatus.paid => 'Paid',
        OrderStatus.cancelled => 'Cancelled',
        OrderStatus.unknown => '—',
      };

  Color get color => switch (this) {
        OrderStatus.open => AppColors.terracotta,
        OrderStatus.paid => AppColors.sageText,
        OrderStatus.cancelled => AppColors.textMuted,
        OrderStatus.unknown => AppColors.textMuted,
      };
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.linePrice,
    this.options,
  });

  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double linePrice;
  final String? options;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    return OrderItem(
      id: json['id'] as int,
      productId: json['productId'] as int,
      productName: p is Map ? (p['name'] as String? ?? '') : '',
      quantity: json['quantity'] as int,
      linePrice: parseAmount(json['linePrice']),
      options: json['options'] as String?,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.itemCount,
    this.tableId,
    this.tableNumber,
    this.tableFloor,
    this.customerName,
    this.createdByName,
  });

  final int id;
  final String orderNo;
  final OrderStatus status;
  final List<OrderItem> items;
  final double subtotal;
  final int itemCount;
  final int? tableId;
  final int? tableNumber;
  final String? tableFloor;
  final String? customerName;
  final String? createdByName;

  factory Order.fromJson(Map<String, dynamic> json) {
    final table = json['table'];
    final customer = json['customer'];
    final createdBy = json['createdBy'];
    return Order(
      id: json['id'] as int,
      orderNo: json['orderNo'] as String? ?? 'ORD-${json['id']}',
      status: OrderStatus.fromApi(json['status'] as String? ?? 'OPEN'),
      items: (json['items'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: parseAmount(json['subtotal']),
      itemCount: json['itemCount'] as int? ?? 0,
      tableId: json['tableId'] as int?,
      tableNumber: table is Map ? table['number'] as int? : null,
      tableFloor: table is Map ? table['floor'] as String? : null,
      customerName: customer is Map ? customer['fullName'] as String? : null,
      createdByName: createdBy is Map ? createdBy['fullName'] as String? : null,
    );
  }

  /// "Dine-in · T-05 · by Linh" hoặc "Takeaway".
  String get contextLine {
    final where = tableId == null ? 'Takeaway' : 'Dine-in · $tableCode';
    final by = createdByName != null ? ' · by ${createdByName!.split(' ').first}' : '';
    return '$where$by';
  }

  String get tableCode {
    if (tableNumber == null) return 'TA';
    final prefix = (tableFloor != null && tableFloor!.isNotEmpty) ? tableFloor![0].toUpperCase() : 'T';
    return '$prefix-${tableNumber.toString().padLeft(2, '0')}';
  }

  String get subtotalLabel => formatVnd(subtotal);
}
