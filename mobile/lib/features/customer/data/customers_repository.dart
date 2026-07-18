import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/customer_model.dart';

class CustomersRepository {
  CustomersRepository(this._api);
  final ApiClient _api;

  Future<List<Customer>> list({String? search}) async {
    final res = await _api.dio.get('/customers', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerDetail> detail(int id) async {
    final res = await _api.dio.get('/customers/$id');
    return CustomerDetail.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Customer> create(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/customers', data: body);
    return Customer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Customer> update(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/customers/$id', data: body);
    return Customer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.dio.delete('/customers/$id');
}

final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(ref.watch(apiClientProvider)),
);

final customersProvider = FutureProvider.autoDispose<List<Customer>>(
  (ref) => ref.watch(customersRepositoryProvider).list(),
);

final customerDetailProvider = FutureProvider.autoDispose.family<CustomerDetail, int>(
  (ref, id) => ref.watch(customersRepositoryProvider).detail(id),
);
