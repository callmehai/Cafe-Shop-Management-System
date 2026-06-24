import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../theme/app_colors.dart';

/// Cầu nối Riverpod -> GoRouter: trạng thái auth đổi thì refresh để redirect (CR-06) chạy lại.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AppUser?>>(authControllerProvider, (_, next) {
      // Lần đầu auth ra khỏi trạng thái loading = đã khôi phục phiên xong.
      if (!next.isLoading) _bootstrapped = true;
      notifyListeners();
    });
  }

  final Ref _ref;
  bool _bootstrapped = false;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authControllerProvider);
    final loc = state.matchedLocation;

    // Splash CHỈ cho lần khôi phục phiên đầu tiên (không can thiệp lúc login/logout).
    if (!_bootstrapped && auth.isLoading) return loc == '/splash' ? null : '/splash';

    final loggedIn = auth.valueOrNull != null;

    // Khôi phục xong: rời splash về đích phù hợp.
    if (loc == '/splash') return loggedIn ? '/home' : '/login';

    final atLogin = loc == '/login';
    if (!loggedIn) return atLogin ? null : '/login';
    if (atLogin) return '/home';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
    );
  }
}
