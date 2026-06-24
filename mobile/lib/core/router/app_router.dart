import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';

// TODO: thêm guard redirect về /login nếu chưa có token (CR-06)
//       và route cho order/payment/menu/inventory/customer/report.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
  ],
);
