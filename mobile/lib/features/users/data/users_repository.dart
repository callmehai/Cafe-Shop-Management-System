import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/managed_user.dart';

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<List<ManagedUser>> list({String? search}) async {
    final res = await _api.dio.get('/users', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return (res.data as List).map((e) => ManagedUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ManagedUser> create(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/users', data: body);
    return ManagedUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ManagedUser> update(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/users/$id', data: body);
    return ManagedUser.fromJson(res.data as Map<String, dynamic>);
  }

  /// Soft-delete (deactivate) — backend đặt isActive=false.
  Future<void> deactivate(int id) => _api.dio.delete('/users/$id');
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);

final usersProvider = FutureProvider<List<ManagedUser>>(
  (ref) => ref.watch(usersRepositoryProvider).list(),
);
