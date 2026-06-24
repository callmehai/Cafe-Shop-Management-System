import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/menu_models.dart';

class MenuRepository {
  MenuRepository(this._api);
  final ApiClient _api;

  // ---------- Products ----------
  Future<List<Product>> listProducts({String? search}) async {
    final res = await _api.dio.get('/products', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/products', data: body);
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/products/$id', data: body);
    return Product.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) => _api.dio.delete('/products/$id');

  // ---------- Categories ----------
  Future<List<Category>> listCategories() async {
    final res = await _api.dio.get('/categories');
    return (res.data as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> createCategory(String name) async {
    final res = await _api.dio.post('/categories', data: {'name': name});
    return Category.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Category> updateCategory(int id, String name) async {
    final res = await _api.dio.patch('/categories/$id', data: {'name': name});
    return Category.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) => _api.dio.delete('/categories/$id');
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);

/// Danh sách sản phẩm (toàn bộ — UI tự nhóm theo category & lọc client-side).
final productsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(menuRepositoryProvider).listProducts(),
);

/// Danh sách category kèm số sản phẩm.
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(menuRepositoryProvider).listCategories(),
);
