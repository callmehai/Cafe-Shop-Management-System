import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/toast.dart';
import '../../menu/data/menu_repository.dart';
import '../../menu/domain/menu_models.dart';
import '../../tables/data/tables_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../payment/presentation/payment_page.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';
import 'add_item_sheet.dart';

class _EditLine {
  _EditLine({required this.productId, required this.name, required this.quantity, required this.unitPrice, this.options});
  final int productId;
  final String name;
  int quantity;
  double unitPrice;
  String? options;
  double get lineTotal => unitPrice * quantity;
}

/// Chi tiết & sửa order (Figma "10 Order Details"). Sửa cục bộ rồi Save (PATCH).
class OrderDetailsPage extends ConsumerStatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends ConsumerState<OrderDetailsPage> {
  List<_EditLine>? _lines;
  bool _saving = false;
  OrderStatus _status = OrderStatus.open;

  void _seed(Order order) {
    _status = order.status;
    _lines ??= order.items
        .map((it) => _EditLine(
              productId: it.productId,
              name: it.productName,
              quantity: it.quantity,
              unitPrice: it.quantity == 0 ? it.linePrice : it.linePrice / it.quantity,
              options: it.options,
            ))
        .toList();
  }

  double get _subtotal => (_lines ?? []).fold(0, (s, l) => s + l.lineTotal);
  bool get _editable {
    if (_status != OrderStatus.open) return false;
    final user = ref.watch(currentUserProvider);
    return user?.role != UserRole.barista;
  }

  Future<void> _save() async {
    final lines = _lines ?? [];
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An order needs at least one item.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(ordersRepositoryProvider).updateOrder(
            widget.orderId,
            items: lines.map((l) => {
                  'productId': l.productId,
                  'quantity': l.quantity,
                  if (l.options != null) 'options': l.options,
                }).toList(),
          );
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderQueueProvider);
      if (mounted) {
        showTopRightToast(context, 'Order saved');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel order'),
        content: const Text('Cancel this order? This frees the table and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ordersRepositoryProvider).cancelOrder(widget.orderId);
      ref.invalidate(orderQueueProvider);
      ref.invalidate(tablesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  Future<void> _addItem() async {
    final product = await _pickProduct();
    if (product == null || !mounted) return;
    final res = await showAddItemSheet(context, product);
    if (res == null) return;
    setState(() {
      _lines!.add(_EditLine(
        productId: product.id,
        name: product.name,
        quantity: res.quantity,
        unitPrice: product.price,
        options: res.options,
      ));
    });
  }

  Future<Product?> _pickProduct() {
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final available = products.where((p) => p.isAvailable).toList();
    return showModalBottomSheet<Product>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: available
            .map((p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.priceLine, style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.of(context).pop(p),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Order Details'),
        actions: [
          if (_editable)
            IconButton(
              tooltip: 'Cancel order',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _cancelOrder,
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
        data: (order) {
          _seed(order);
          final lines = _lines!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order ${order.orderNo}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              Text(order.contextLine, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                        _StatusPill(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...lines.asMap().entries.map((e) => _ItemRow(
                          line: e.value,
                          editable: _editable,
                          onInc: () => setState(() => e.value.quantity++),
                          onDec: () => setState(() {
                            if (e.value.quantity > 1) {
                              e.value.quantity--;
                            } else {
                              lines.removeAt(e.key);
                            }
                          }),
                        )),
                    if (_editable)
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                    const SizedBox(height: 8),
                    const Divider(color: AppColors.border),
                    _TotalRow(label: 'Subtotal', value: formatVnd(_subtotal)),
                    const _TotalRow(label: 'Discount', value: '−0₫', muted: true),
                    _TotalRow(label: 'Total', value: formatVnd(_subtotal), bold: true),
                  ],
                ),
              ),
              if (_editable)
                Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _save,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppColors.terracotta),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                              : const Text('Save', style: TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () async {
                            // Lưu thay đổi item (nếu có) trước khi sang thanh toán.
                            await _save();
                            if (!context.mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PaymentPage(orderId: widget.orderId)),
                            );
                            ref.invalidate(orderDetailProvider(widget.orderId));
                          },
                          child: Text('Charge ${formatVnd(_subtotal)}'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line, required this.editable, required this.onInc, required this.onDec});
  final _EditLine line;
  final bool editable;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (editable) ...[
            _QtyBtn(icon: Icons.remove, onTap: onDec),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _QtyBtn(icon: Icons.add, onTap: onInc),
          ] else
            Text('${line.quantity}×', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (line.options != null && line.options!.isNotEmpty)
                  Text(line.options!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(formatVnd(line.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: AppColors.terracottaDark)),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false, this.muted = false});
  final String label;
  final String value;
  final bool bold;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: muted ? AppColors.textMuted : AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label, style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
