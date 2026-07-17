import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../account/presentation/account_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../customer/presentation/customer_management_page.dart';
import '../../inventory/presentation/inventory_management_page.dart';
import '../../menu/presentation/menu_management_page.dart';
import '../../order/presentation/order_queue_page.dart';
import '../../report/presentation/reports_page.dart';
import '../../users/presentation/users_management_page.dart';

/// 1 tab ở bottom navigation.
class _NavTab {
  const _NavTab({required this.label, required this.icon, required this.body});
  final String label;
  final IconData icon;
  final Widget body;
}

final homeShellIndexProvider = StateProvider<int>((ref) => 0);

/// Khung chính sau đăng nhập: AppBar + body theo tab + bottom navigation theo role.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(AppConstants.inactivityTimeout, _handleLogout);
  }

  void _handleLogout() {
    if (mounted) {
      ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink(); // guard sẽ điều hướng về /login

    final tabs = _tabsForRole(user.role);
    final activeIndex = ref.watch(homeShellIndexProvider);
    final index = activeIndex.clamp(0, tabs.length - 1);

    return Listener(
      onPointerDown: (_) => _resetInactivityTimer(),
      onPointerSignal: (_) => _resetInactivityTimer(),
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: tabs.map((t) => t.body).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => ref.read(homeShellIndexProvider.notifier).state = i,
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          destinations: tabs
              .map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label))
              .toList(),
        ),
      ),
    );
  }

  List<_NavTab> _tabsForRole(UserRole role) {
    const home = _NavTab(label: 'Home', icon: Icons.home_rounded, body: DashboardView());
    const account = _NavTab(label: 'Account', icon: Icons.person_outline_rounded, body: AccountView());

    switch (role) {
      case UserRole.manager:
        return const [
          home,
          _NavTab(label: 'Menu', icon: Icons.restaurant_menu, body: MenuManagementPage()),
          _NavTab(label: 'Inventory', icon: Icons.inventory_2_outlined, body: InventoryManagementPage()),
          _NavTab(label: 'Reports', icon: Icons.bar_chart_rounded, body: ReportsPage()),
          account,
        ];
      case UserRole.administrator:
        return const [
          home,
          _NavTab(label: 'Users', icon: Icons.group_outlined, body: UsersManagementPage()),
          _NavTab(label: 'Customers', icon: Icons.badge_outlined, body: CustomerManagementPage()),
          _NavTab(label: 'Reports', icon: Icons.bar_chart_rounded, body: ReportsPage()),
          account,
        ];
      case UserRole.barista:
        return const [
          home,
          _NavTab(label: 'Queue', icon: Icons.list_alt_rounded, body: OrderQueuePage(title: 'Order Queue')),
          account,
        ];
      case UserRole.cashier:
      case UserRole.unknown:
        return const [
          home,
          _NavTab(label: 'Orders', icon: Icons.receipt_long_outlined, body: OrderQueuePage(title: 'Orders', allowCreate: true)),
          _NavTab(label: 'Queue', icon: Icons.list_alt_rounded, body: OrderQueuePage(title: 'Order Queue')),
          account,
        ];
    }
  }
}
