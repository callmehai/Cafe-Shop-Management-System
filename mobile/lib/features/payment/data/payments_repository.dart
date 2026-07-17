import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/payment_models.dart';

class PaymentsRepository {
  PaymentsRepository(this._api);
  final ApiClient _api;

  Future<PaymentResult> process({
    required int orderId,
    required PaymentMethod method,
    int? customerId,
    int? pointsRedeemed,
    double? discount,
    double? cashTendered,
    int? approvalManagerId,
  }) async {
    final res = await _api.dio.post('/payments', data: {
      'orderId': orderId,
      'method': method.api,
      if (customerId != null) 'customerId': customerId,
      if (pointsRedeemed != null && pointsRedeemed > 0) 'pointsRedeemed': pointsRedeemed,
      if (discount != null && discount > 0) 'discount': discount,
      if (cashTendered != null) 'cashTendered': cashTendered,
      if (approvalManagerId != null) 'approvalManagerId': approvalManagerId,
    });
    return PaymentResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> getVnPayUrl(int orderId) async {
    final res = await _api.dio.post('/payments/$orderId/vnpay-url');
    return res.data['url'] as String;
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
);
