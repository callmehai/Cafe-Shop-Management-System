import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../customer/domain/customer_model.dart';
import '../../menu/data/menu_repository.dart';
import '../../menu/domain/menu_models.dart';
import '../../tables/data/tables_repository.dart';
import '../../tables/domain/table_model.dart';
import '../data/orders_repository.dart';
import 'add_item_sheet.dart';
import 'customer_picker_page.dart';
import 'order_details_page.dart';
import 'table_picker_page.dart';

class _CartLine {
  _CartLine({required this.product, required this.quantity, this.options});
  final Product product;
  int quantity;
  String? options;
  double get lineTotal => product.price * quantity;
}

/// Tạo order mới (Figma "08 Create Order"). Giỏ hàng cục bộ -> tạo order khi Review.
class CreateOrderPage extends ConsumerStatefulWidget {
  const CreateOrderPage({super.key});

  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  final List<_CartLine> _cart = [];
  TableModel? _table;
  Customer? _customer;
  String _query = '';
  String? _category;
  bool _submitting = false;

  int get _itemCount => _cart.fold(0, (n, l) => n + l.quantity);
  double get _total => _cart.fold(0, (s, l) => s + l.lineTotal);

  Future<void> _addProduct(Product p) async {
    final result = await showAddItemSheet(context, p);
    if (result == null) return;
    setState(() => _cart.add(_CartLine(product: p, quantity: result.quantity, options: result.options)));
  }

  Future<void> _pickTable() async {
    final picked = await Navigator.of(context).push<TableModel>(
      MaterialPageRoute(builder: (_) => const TablePickerPage()),
    );
    if (picked != null) setState(() => _table = picked);
  }

  Future<void> _pickCustomer() async {
    final result = await Navigator.of(context).push<CustomerPickerResult>(
      MaterialPageRoute(builder: (_) => CustomerPickerPage(selectedId: _customer?.id)),
    );
    // null = back/hủy (giữ nguyên); result.customer == null = bỏ gán khách.
    if (result != null) setState(() => _customer = result.customer);
  }

  Future<void> _review() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item.')), // BR-01
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref.read(ordersRepositoryProvider).createOrder(
            tableId: _table?.id,
            customerId: _customer?.id,
            items: _cart
                .map((l) => {
                      'productId': l.product.id,
                      'quantity': l.quantity,
                      if (l.options != null) 'options': l.options,
                    })
                .toList(),
          );
      ref.invalidate(orderQueueProvider);
      ref.invalidate(tablesProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderDetailsPage(orderId: order.id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('New Order'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: AppColors.danger, size: 18),
            label: const Text('Cancel', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Table + Customer selectors
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SelectorCard(
                    icon: Icons.grid_view_rounded,
                    label: 'Table',
                    value: _table == null ? 'Takeaway' : '${_table!.code} · ${_table!.capacity} seats',
                    onTap: _pickTable,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SelectorCard(
                    icon: _customer == null ? Icons.person_add_alt : Icons.person,
                    label: 'Customer',
                    value: _customer == null
                        ? 'Add customer'
                        : '${_customer!.fullName} · ${_customer!.loyaltyPoints} pts',
                    onTap: _pickCustomer,
                  ),
                ),
              ],
            ),
          ),
          // Search + category filter + grid
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
              error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
              data: (all) {
                final available = all.where((p) => p.isAvailable).toList();
                final categories = {for (final p in available) p.categoryName}.toList();
                var list = available;
                if (_category != null) list = list.where((p) => p.categoryName == _category).toList();
                if (_query.isNotEmpty) {
                  list = list.where((p) => p.name.toLowerCase().contains(_query)).toList();
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          hintText: 'Search menu…',
                          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _CategoryChip(label: 'All', selected: _category == null, onTap: () => setState(() => _category = null)),
                          ...categories.map((c) => _CategoryChip(
                                label: c,
                                selected: _category == c,
                                onTap: () => setState(() => _category = c),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: list.map((p) => _ProductTile(product: p, onTap: () => _addProduct(p))).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _ReviewBar(
            itemCount: _itemCount,
            total: _total,
            busy: _submitting,
            onReview: _review,
          ),
        ],
      ),
    );
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.terracotta, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.espresso,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? AppColors.espresso : AppColors.border),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  Widget _fallbackLetter() {
    return Center(
      child: Text(
        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: product.fullImageUrl != null
                      ? Image.network(
                          product.fullImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _fallbackLetter(),
                        )
                      : _fallbackLetter(),
                ),
              ),
              const Spacer(),
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(product.priceLine, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({required this.itemCount, required this.total, required this.busy, required this.onReview});
  final int itemCount;
  final double total;
  final bool busy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$itemCount items', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text(formatVnd(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onReview,
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Review order'),
            ),
          ),
        ],
      ),
    );
  }
}
