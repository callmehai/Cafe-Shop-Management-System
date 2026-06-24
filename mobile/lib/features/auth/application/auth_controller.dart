import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Trạng thái phiên đăng nhập toàn app.
/// - loading  : đang khôi phục phiên lúc mở app
/// - data null : chưa đăng nhập
/// - data user : đã đăng nhập
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() => _repo.restoreSession();

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.login(username, password));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// Gọi từ interceptor khi gặp 401 — đẩy app về trạng thái chưa đăng nhập.
  void handleUnauthorized() {
    _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Tiện ích: user hiện tại (null nếu chưa đăng nhập).
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).valueOrNull,
);
