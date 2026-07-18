import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/order_models.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;

  Future<List<Order>> queue() async {
    final res = await _api.dio.get('/orders/queue');
    return (res.data as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(int id) async {
    final res = await _api.dio.get('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  /// items: [{productId, quantity, options?}]
  Future<Order> createOrder({
    int? tableId,
    int? customerId,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _api.dio.post('/orders', data: {
      if (tableId != null) 'tableId': tableId,
      if (customerId != null) 'customerId': customerId,
      'items': items,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> updateOrder(int id, {List<Map<String, dynamic>>? items, int? tableId}) async {
    final res = await _api.dio.patch('/orders/$id', data: {
      if (items != null) 'items': items,
      if (tableId != null) 'tableId': tableId,
    });
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Order> cancelOrder(int id) async {
    final res = await _api.dio.delete('/orders/$id');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  // UC12: đẩy trạng thái chuẩn bị 1 món.
  Future<Order> updateItemPrep(int orderId, int itemId, String status) async {
    final res = await _api.dio.patch('/orders/$orderId/items/$itemId/prep', data: {'status': status});
    return Order.fromJson(res.data as Map<String, dynamic>);
  }

  // UC12: đánh dấu cả order chuẩn bị xong.
  Future<Order> markPrepDone(int orderId) async {
    final res = await _api.dio.patch('/orders/$orderId/prep-done');
    return Order.fromJson(res.data as Map<String, dynamic>);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) => OrdersRepository(ref.watch(apiClientProvider)),
);

/// Hàng đợi order đang OPEN (màn 11).
final orderQueueProvider = FutureProvider.autoDispose<List<Order>>(
  (ref) => ref.watch(ordersRepositoryProvider).queue(),
);

/// Chi tiết 1 order (màn 10).
final orderDetailProvider = FutureProvider.autoDispose.family<Order, int>(
  (ref, id) => ref.watch(ordersRepositoryProvider).getOrder(id),
);
