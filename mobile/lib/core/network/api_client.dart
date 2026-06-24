import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../constants/app_constants.dart';

// Dio client + interceptor tự gắn JWT vào header (security §8).
class ApiClient {
  ApiClient(this._storage) {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 3), // perf §8: phản hồi <3s peak
      receiveTimeout: const Duration(seconds: 3),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ));
  }

  late final Dio dio;
  final FlutterSecureStorage _storage;
}
