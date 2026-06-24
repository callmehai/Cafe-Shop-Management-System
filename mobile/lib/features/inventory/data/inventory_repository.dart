import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/ingredient_model.dart';

class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  Future<List<Ingredient>> listIngredients() async {
    final res = await _api.dio.get('/inventory/ingredients');
    return (res.data as List).map((e) => Ingredient.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Ingredient> createIngredient(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/inventory/ingredients', data: body);
    return Ingredient.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Ingredient> updateIngredient(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/inventory/ingredients/$id', data: body);
    return Ingredient.fromJson(res.data as Map<String, dynamic>);
  }

  /// items: [{ingredientId, quantity, unitCost}]
  Future<void> receiveStock({required String supplierName, required List<Map<String, dynamic>> items}) {
    return _api.dio.post('/inventory/stock-in', data: {'supplierName': supplierName, 'items': items});
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.watch(apiClientProvider)),
);

final ingredientsProvider = FutureProvider<List<Ingredient>>(
  (ref) => ref.watch(inventoryRepositoryProvider).listIngredients(),
);
