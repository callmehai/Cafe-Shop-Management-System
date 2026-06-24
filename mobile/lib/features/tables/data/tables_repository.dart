import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/table_model.dart';

class TablesRepository {
  TablesRepository(this._api);
  final ApiClient _api;

  Future<List<TableModel>> list() async {
    final res = await _api.dio.get('/tables');
    return (res.data as List).map((e) => TableModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TableModel> create(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/tables', data: body);
    return TableModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TableModel> update(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/tables/$id', data: body);
    return TableModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> remove(int id) => _api.dio.delete('/tables/$id');
}

final tablesRepositoryProvider = Provider<TablesRepository>(
  (ref) => TablesRepository(ref.watch(apiClientProvider)),
);

final tablesProvider = FutureProvider<List<TableModel>>(
  (ref) => ref.watch(tablesRepositoryProvider).list(),
);
