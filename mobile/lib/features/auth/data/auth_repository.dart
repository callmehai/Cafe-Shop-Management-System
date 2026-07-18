import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  // UC10 Login -> POST /auth/login
  Future<AppUser> login(String username, String password) async {
    final res = await _api.dio.post('/auth/login', data: {
      'username': username.trim(), // CR-08
      'password': password,
    });
    final token = res.data['accessToken'] as String;
    final user = AppUser.fromJson(res.data['user'] as Map<String, dynamic>);
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
    return user;
  }

  /// CR-06: khôi phục phiên khi mở app. Trả null nếu chưa đăng nhập / phiên hết hạn.
  Future<AppUser?> restoreSession() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return null;
    try {
      final res = await _api.dio.get('/auth/me');
      final user = AppUser.fromJson(res.data as Map<String, dynamic>);
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token không còn hợp lệ -> dọn sạch.
        await logout();
        return null;
      }
      // Lỗi mạng tạm thời: dùng hồ sơ cache để vẫn vào được app.
      final cached = await _storage.read(key: AppConstants.userKey);
      if (cached != null) {
        return AppUser.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (e) {
      // Bỏ qua lỗi mạng để đảm bảo vẫn đăng xuất được trên local.
    } finally {
      await _storage.delete(key: AppConstants.tokenKey);
      await _storage.delete(key: AppConstants.userKey);
    }
  }

  /// Xác thực 1 tài khoản (vd Manager duyệt giảm giá BR-06) mà KHÔNG đụng phiên hiện tại.
  /// Trả về user nếu đúng mật khẩu; ném lỗi nếu sai.
  Future<AppUser> verifyCredentials(String username, String password) async {
    final res = await _api.dio.post('/auth/login', data: {
      'username': username.trim(),
      'password': password,
    });
    return AppUser.fromJson(res.data['user'] as Map<String, dynamic>);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});
