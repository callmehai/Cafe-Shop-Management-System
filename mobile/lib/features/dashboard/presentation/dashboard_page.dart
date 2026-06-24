import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../customer/presentation/customer_management_page.dart';
import '../../inventory/presentation/inventory_management_page.dart';
import '../../menu/presentation/menu_management_page.dart';
import '../../order/presentation/create_order_page.dart';
import '../../order/presentation/order_queue_page.dart';
import '../../report/data/reports_repository.dart';
import '../../report/domain/report_models.dart';
import '../../report/presentation/reports_page.dart';
import '../../tables/presentation/tables_management_page.dart';
import '../../users/presentation/users_management_page.dart';

/// Home tab — greeting + số liệu thật (dashboardStatsProvider) + quick actions theo role.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final stats = ref.watch(dashboardStatsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _GreetingHeader(user: user),
            const SizedBox(height: 20),
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
              ),
              error: (e, _) => const _RevenueCard(amount: '—'),
              data: (s) => _StatsSection(role: user.role, stats: s),
            ),
            const SizedBox(height: 28),
            const Text('QUICK ACTIONS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            _QuickActions(role: user.role),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.role, required this.stats});
  final UserRole role;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.administrator;
    return Column(
      children: [
        _RevenueCard(amount: isAdmin ? '${stats.userCount} users' : stats.revenueTodayLabel,
            caption: isAdmin ? '${stats.activeUsers} active accounts' : '${stats.ordersToday} orders today',
            title: isAdmin ? 'Total users' : "Today's revenue"),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _StatCard(value: '${stats.openOrders}', label: 'Open orders', icon: Icons.receipt_long_outlined)),
            const SizedBox(width: 14),
            Expanded(
              child: _StatCard(
                value: '${stats.tablesFree}',
                suffix: '/${stats.tablesTotal}',
                label: 'Tables free',
                icon: Icons.grid_view_rounded,
                sage: true,
              ),
            ),
          ],
        ),
        if (role == UserRole.manager && stats.lowStock.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.terracotta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.terracottaDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${stats.lowStockCount} ingredients low on stock',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.terracottaDark)),
                      Text(stats.lowStock.join(', '),
                          style: const TextStyle(fontSize: 12, color: AppColors.terracottaDark)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
          child: Text(user.initials, style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good morning', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.terracotta.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(user.role.label,
              style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.amount, this.caption, this.title = "Today's revenue"});
  final String amount;
  final String? caption;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          Text(amount, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon, this.suffix, this.sage = false});
  final String value;
  final String? suffix;
  final String label;
  final IconData icon;
  final bool sage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sage ? AppColors.sage : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: sage ? AppColors.sageText : AppColors.terracotta, size: 22),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              if (suffix != null) Text(suffix!, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.title, this.subtitle, this.icon, this.builder, {this.primary = false});
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final bool primary;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final actions = _actionsForRole(role);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.45,
      children: actions
          .map((a) => _ActionCard(
                action: a,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: a.builder)),
              ))
          .toList(),
    );
  }

  static List<_QuickAction> _actionsForRole(UserRole role) {
    switch (role) {
      case UserRole.manager:
        return [
          _QuickAction('Menu', 'Manage items', Icons.restaurant_menu, (_) => const MenuManagementPage(), primary: true),
          _QuickAction('Inventory', 'Stock & receive', Icons.inventory_2_outlined, (_) => const InventoryManagementPage()),
          _QuickAction('Reports', 'Sales insights', Icons.bar_chart_rounded, (_) => const ReportsPage()),
          _QuickAction('Customers', 'Loyalty', Icons.badge_outlined, (_) => const CustomerManagementPage()),
          _QuickAction('Tables', 'Floor map', Icons.grid_view_rounded, (_) => const TablesManagementPage()),
        ];
      case UserRole.administrator:
        return [
          _QuickAction('Users', 'Manage staff', Icons.group_outlined, (_) => const UsersManagementPage(), primary: true),
          _QuickAction('Customers', 'Loyalty', Icons.badge_outlined, (_) => const CustomerManagementPage()),
          _QuickAction('Reports', 'Sales insights', Icons.bar_chart_rounded, (_) => const ReportsPage()),
          _QuickAction('Menu', 'Catalog', Icons.restaurant_menu, (_) => const MenuManagementPage()),
        ];
      case UserRole.barista:
        return [
          _QuickAction('Order Queue', 'In progress', Icons.list_alt_rounded, (_) => const OrderQueuePage(title: 'Order Queue'), primary: true),
        ];
      case UserRole.cashier:
      case UserRole.unknown:
        return [
          _QuickAction('New Order', 'Start a ticket', Icons.add_rounded, (_) => const CreateOrderPage(), primary: true),
          _QuickAction('Order Queue', 'In progress', Icons.list_alt_rounded, (_) => const OrderQueuePage(title: 'Order Queue')),
          _QuickAction('Customers', 'Loyalty', Icons.badge_outlined, (_) => const CustomerManagementPage()),
        ];
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = action.primary;
    return Material(
      color: primary ? AppColors.terracotta : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: primary ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withValues(alpha: 0.18) : AppColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: primary ? Colors.white : AppColors.terracotta, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary ? Colors.white : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(action.subtitle,
                      style: TextStyle(fontSize: 12, color: primary ? Colors.white70 : AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
