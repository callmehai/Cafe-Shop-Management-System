import 'package:flutter_test/flutter_test.dart';
import 'package:csms_mobile/features/order/domain/order_models.dart';

void main() {
  group('Order Model Tests', () {
    test('OrderStatus fromApi matches correctly', () {
      expect(OrderStatus.fromApi('OPEN'), OrderStatus.open);
      expect(OrderStatus.fromApi('PAID'), OrderStatus.paid);
      expect(OrderStatus.fromApi('CANCELLED'), OrderStatus.cancelled);
      expect(OrderStatus.fromApi('INVALID'), OrderStatus.unknown);
    });

    test('PrepStatus next transition works correctly', () {
      expect(PrepStatus.pending.next, PrepStatus.making);
      expect(PrepStatus.making.next, PrepStatus.done);
      expect(PrepStatus.done.next, PrepStatus.pending);
    });

    test('Order fromJson parses simple takeaway correctly', () {
      final json = {
        'id': 12,
        'orderNo': 'ORD-1012',
        'status': 'OPEN',
        'subtotal': '45000.00',
        'itemCount': 2,
        'tableId': null,
        'items': [
          {
            'id': 5,
            'productId': 101,
            'quantity': 2,
            'linePrice': '45000.00',
            'prepStatus': 'PENDING',
            'product': {'name': 'Espresso'}
          }
        ]
      };

      final order = Order.fromJson(json);

      expect(order.id, 12);
      expect(order.orderNo, 'ORD-1012');
      expect(order.status, OrderStatus.open);
      expect(order.subtotal, 45000.0);
      expect(order.itemCount, 2);
      expect(order.items.length, 1);
      expect(order.items[0].productName, 'Espresso');
      expect(order.contextLine, 'Takeaway');
    });

    test('Order contextLine formats dine-in details correctly', () {
      final json = {
        'id': 15,
        'orderNo': 'ORD-1015',
        'status': 'OPEN',
        'subtotal': '90000.00',
        'itemCount': 3,
        'tableId': 3,
        'table': {
          'id': 3,
          'number': 7,
          'floor': 'Floor 1',
        },
        'createdBy': {
          'id': 2,
          'fullName': 'Nguyen Van A',
        },
        'items': []
      };

      final order = Order.fromJson(json);

      expect(order.contextLine, 'Dine-in · F-07 · by Nguyen');
      expect(order.tableCode, 'F-07');
    });
  });
}
