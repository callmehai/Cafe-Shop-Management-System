import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer/data/customers_repository.dart';
import '../../customer/domain/customer_model.dart';
import '../../customer/presentation/customer_form_page.dart';

/// Chọn khách hàng cho order (màn "08 Create Order" -> Add customer).
/// Trả về [Customer] đã chọn, hoặc [CustomerPickerResult.cleared] khi bỏ gán khách.
class CustomerPickerPage extends ConsumerStatefulWidget {
  const CustomerPickerPage({super.key, this.selectedId});

  /// Khách đang được gán cho order (nếu có) — để hiện dấu tick.
  final int? selectedId;

  @override
  ConsumerState<CustomerPickerPage> createState() => _CustomerPickerPageState();
}

class _CustomerPickerPageState extends ConsumerState<CustomerPickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Select Customer'),
        actions: [
          if (widget.selectedId != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(const CustomerPickerResult.cleared()),
              child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search name or phone…',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(apiErrorMessage(e),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(customersProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (all) {
                final list = _query.isEmpty
                    ? all
                    : all
                        .where((c) =>
                            c.fullName.toLowerCase().contains(_query) ||
                            (c.phone ?? '').toLowerCase().contains(_query))
                        .toList();
                if (list.isEmpty) {
                  return const Center(
                    child: Text('No customers found.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(customersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _CustomerRow(
                      customer: list[i],
                      selected: list[i].id == widget.selectedId,
                      onTap: () => Navigator.of(context).pop(CustomerPickerResult(list[i])),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customer-picker-fab',
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: _createCustomer,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('New customer'),
      ),
    );
  }

  /// Tạo nhanh khách mới rồi gán luôn cho order.
  Future<void> _createCustomer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CustomerFormPage()),
    );
    if (created != true || !mounted) return;
    ref.invalidate(customersProvider);
    // Khách mới nhất = id lớn nhất; chọn luôn để đỡ phải tìm lại.
    final refreshed = await ref.read(customersProvider.future);
    if (!mounted || refreshed.isEmpty) return;
    final newest = refreshed.reduce((a, b) => a.id >= b.id ? a : b);
    Navigator.of(context).pop(CustomerPickerResult(newest));
  }
}

/// Kết quả trả về từ picker: chọn 1 khách, hoặc bỏ gán khách khỏi order.
class CustomerPickerResult {
  const CustomerPickerResult(this.customer);
  const CustomerPickerResult.cleared() : customer = null;

  final Customer? customer;
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.selected, required this.onTap});

  final Customer customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.terracotta : AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: AppColors.terracotta.withValues(alpha: 0.15),
          child: Text(
            customer.initials,
            style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${customer.phone ?? 'No phone'} · ${customer.loyaltyPoints} pts',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.terracotta)
            : const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}
