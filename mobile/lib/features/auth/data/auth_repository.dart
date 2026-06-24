import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  // UC10 Login -> POST /auth/login
  Future<void> login(String username, String password) async {
    final res = await _api.dio.post('/auth/login', data: {
      'username': username.trim(), // CR-08
      'password': password,
    });
    final token = res.data['accessToken'] as String;
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<void> logout() => _storage.delete(key: AppConstants.tokenKey);
}
