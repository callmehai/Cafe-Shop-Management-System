import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../constants/app_constants.dart';

/// Dio client: tự gắn JWT vào header và phát tín hiệu khi gặp 401 (token hết hạn/thu hồi).
class ApiClient {
  ApiClient(this._storage, {this.onUnauthorized}) {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      // Dev: nới timeout để chịu được cold-start. SRS §8 yêu cầu <3s ở môi trường thật.
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        // 401 ở các route đã đăng nhập = phiên không còn hợp lệ -> báo về app để logout (CR-06).
        // Bỏ qua chính endpoint login để không nhầm "sai mật khẩu" thành "hết phiên".
        final isLogin = e.requestOptions.path.contains('/auth/login');
        if (e.response?.statusCode == 401 && !isLogin) {
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));
  }

  late final Dio dio;
  final FlutterSecureStorage _storage;

  /// Gọi khi nhận 401 ở route cần đăng nhập.
  final void Function()? onUnauthorized;
}

/// Trích message lỗi thân thiện từ DioException (ưu tiên message backend trả về).
String apiErrorMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      return msg.toString();
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
  }
  return fallback;
}
