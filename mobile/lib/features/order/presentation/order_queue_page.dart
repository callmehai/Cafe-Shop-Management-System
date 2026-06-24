import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';
import 'create_order_page.dart';
import 'order_details_page.dart';

/// Hàng đợi order (Figma "11 Order Queue"). [allowCreate] = hiện FAB New Order (Cashier).
class OrderQueuePage extends ConsumerWidget {
  const OrderQueuePage({super.key, this.title = 'Order Queue', this.allowCreate = false});

  final String title;
  final bool allowCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(orderQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: allowCreate
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.terracotta,
              foregroundColor: Colors.white,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateOrderPage()));
                ref.invalidate(orderQueueProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('New order'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: queue.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(orderQueueProvider), child: const Text('Retry')),
              ],
            ),
          ),
          data: (orders) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderQueueProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                PageHeader(
                  title: title,
                  subtitle: orders.isEmpty ? 'No open tickets' : '${orders.length} tickets waiting',
                ),
                if (orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No open orders yet.', style: TextStyle(color: AppColors.textMuted))),
                  ),
                ...orders.map((o) => _TicketCard(
                      order: o,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: o.id)),
                        );
                        ref.invalidate(orderQueueProvider);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.order, required this.onTap});
  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.espresso,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(order.tableCode,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${order.orderNo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(order.contextLine,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    _StatusPill(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                ...order.items.take(3).map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${it.quantity}× ${it.productName}${it.options != null ? ' · ${it.options}' : ''}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                if (order.items.length > 3)
                  Text('+${order.items.length - 3} more',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${order.itemCount} items', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    Text(order.subtotalLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final OrderStatus status;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
