import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_client.dart';
import '../../features/auth/application/auth_controller.dart';

/// Secure storage dùng chung (lưu JWT + hồ sơ user).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// Dio client kèm interceptor JWT. Khi gặp 401 -> nhờ AuthController logout.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(secureStorageProvider),
    // Đọc lazy để tránh phụ thuộc vòng lúc khởi tạo provider.
    onUnauthorized: () => ref.read(authControllerProvider.notifier).handleUnauthorized(),
  );
});
