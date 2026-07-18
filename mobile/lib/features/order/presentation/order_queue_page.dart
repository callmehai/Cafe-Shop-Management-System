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
              heroTag: 'order-queue-fab',
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
                      onOpen: () async {
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

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.order, required this.onOpen});
  final Order order;
  final VoidCallback onOpen;

  Future<void> _advance(WidgetRef ref, BuildContext context, int itemId, PrepStatus next) async {
    try {
      await ref.read(ordersRepositoryProvider).updateItemPrep(order.id, itemId, next.api);
      ref.invalidate(orderQueueProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _markDone(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(ordersRepositoryProvider).markPrepDone(order.id);
      ref.invalidate(orderQueueProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDone = order.items.isNotEmpty && order.items.every((i) => i.prepStatus == PrepStatus.done);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onOpen,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(10)),
                    child: Text(order.tableCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${order.orderNo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(order.contextLine, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Mỗi món: tap để đẩy prep status (UC12).
            ...order.items.map((it) => InkWell(
                  onTap: order.status == OrderStatus.open
                      ? () => _advance(ref, context, it.id, it.prepStatus.next)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${it.quantity}× ${it.productName}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              if (it.options != null && it.options!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  it.options!,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PrepChip(status: it.prepStatus),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (allDone || order.status != OrderStatus.open) ? null : () => _markDone(ref, context),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(allDone ? 'All items done' : 'Mark order completed'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sageText,
                  side: BorderSide(color: (allDone || order.status != OrderStatus.open) ? AppColors.border : AppColors.sageText),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrepChip extends StatelessWidget {
  const _PrepChip({required this.status});
  final PrepStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PrepStatus.pending => AppColors.textMuted,
      PrepStatus.making => AppColors.terracotta,
      PrepStatus.done => AppColors.sageText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

