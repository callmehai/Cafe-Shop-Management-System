import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../customer/data/customers_repository.dart';
import '../../customer/domain/customer_model.dart';
import '../../order/data/orders_repository.dart';
import '../../tables/data/tables_repository.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import 'payment_success_page.dart';

/// Màn thanh toán (Figma "12 Payment" + "13 discount approval"). 1 phương thức (BR-03).
class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key, required this.orderId});
  final int orderId;

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  PaymentMethod _method = PaymentMethod.cash;
  Customer? _customer;
  int _pointsRedeemed = 0;
  final _discount = TextEditingController(); // giảm giá thủ công (₫)
  final _cash = TextEditingController(); // tiền khách đưa
  int? _approvalManagerId;
  String? _approvalManagerName;
  bool _submitting = false;

  static const _pointValue = 100; // 1 điểm = 100₫ (đồng bộ backend)

  @override
  void dispose() {
    _discount.dispose();
    _cash.dispose();
    super.dispose();
  }

  double _loyaltyDiscount() => _pointsRedeemed * _pointValue.toDouble();
  double _manualDiscount() => double.tryParse(_discount.text.trim()) ?? 0;

  double _totalDiscount(double subtotal) {
    final d = _loyaltyDiscount() + _manualDiscount();
    return d > subtotal ? subtotal : d;
  }

  double _amount(double subtotal) => subtotal - _totalDiscount(subtotal);
  bool _needsApproval(double subtotal) => _totalDiscount(subtotal) > subtotal * 0.5;

  int _maxRedeemable(double subtotal) {
    if (_customer == null) return 0;
    // Không đổi điểm vượt quá phần tiền còn lại sau giảm giá thủ công.
    final byMoney = ((subtotal - _manualDiscount()) / _pointValue).floor();
    final capped = byMoney < _customer!.loyaltyPoints ? byMoney : _customer!.loyaltyPoints;
    return capped < 0 ? 0 : capped;
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null) {
      setState(() {
        _customer = picked;
        _pointsRedeemed = 0;
      });
    }
  }

  Future<void> _requestApproval() async {
    final mgr = await showDialog<AppUser>(
      context: context,
      builder: (_) => const _ManagerApprovalDialog(),
    );
    if (mgr != null) {
      setState(() {
        _approvalManagerId = mgr.id;
        _approvalManagerName = mgr.fullName;
      });
    }
  }

  Future<void> _confirm(double subtotal) async {
    final amount = _amount(subtotal);
    if (_method == PaymentMethod.cash && _cash.text.trim().isNotEmpty) {
      final tendered = double.tryParse(_cash.text.trim()) ?? 0;
      if (tendered < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash tendered is less than amount due.')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final result = await ref.read(paymentsRepositoryProvider).process(
            orderId: widget.orderId,
            method: _method,
            customerId: _customer?.id,
            pointsRedeemed: _pointsRedeemed,
            discount: _manualDiscount(),
            cashTendered: _method == PaymentMethod.cash && _cash.text.trim().isNotEmpty
                ? double.tryParse(_cash.text.trim())
                : null,
            approvalManagerId: _approvalManagerId,
          );
      ref.invalidate(orderQueueProvider);
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(tablesProvider);
      ref.invalidate(customersProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PaymentSuccessPage(result: result)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Payment'),
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
        data: (order) {
          final subtotal = order.subtotal;
          final discount = _totalDiscount(subtotal);
          final amount = _amount(subtotal);
          final needsApproval = _needsApproval(subtotal);
          final approved = _approvalManagerId != null;
          final canConfirm = !needsApproval || approved;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Text('#${order.orderNo} · ${order.tableCode}',
                        style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    _AmountDueCard(amount: amount),
                    const SizedBox(height: 20),
                    const _SectionLabel('Payment method'),
                    _MethodSelector(value: _method, onChanged: (m) => setState(() => _method = m)),
                    const SizedBox(height: 20),
                    const _SectionLabel('Loyalty'),
                    _LoyaltyCard(
                      customer: _customer,
                      pointsRedeemed: _pointsRedeemed,
                      maxRedeemable: _maxRedeemable(subtotal),
                      onPick: _pickCustomer,
                      onChanged: (v) => setState(() => _pointsRedeemed = v),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Discount (optional)'),
                    TextField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(hintText: '0', suffixText: '₫'),
                    ),
                    if (needsApproval) ...[
                      const SizedBox(height: 12),
                      _ApprovalBanner(
                        approved: approved,
                        managerName: _approvalManagerName,
                        onRequest: _requestApproval,
                      ),
                    ],
                    if (_method == PaymentMethod.cash) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel('Cash tendered'),
                      TextField(
                        controller: _cash,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: '0', suffixText: '₫'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _Summary(
                      subtotal: subtotal,
                      discount: discount,
                      method: _method,
                      cashTendered: double.tryParse(_cash.text.trim()) ?? 0,
                      amount: amount,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: FilledButton(
                  onPressed: (_submitting || !canConfirm) ? null : () => _confirm(subtotal),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(canConfirm ? 'Confirm payment · ${formatVnd(amount)}' : 'Confirm payment · locked'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmountDueCard extends StatelessWidget {
  const _AmountDueCard({required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('Amount due', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(formatVnd(amount),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.value, required this.onChanged});
  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: PaymentMethod.values.map((m) {
        final on = m == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: on ? AppColors.terracotta : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(m),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: on ? null : Border.all(color: AppColors.border),
                  ),
                  child: Text(m.label,
                      style: TextStyle(
                        color: on ? Colors.white : AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LoyaltyCard extends StatelessWidget {
  const _LoyaltyCard({
    required this.customer,
    required this.pointsRedeemed,
    required this.maxRedeemable,
    required this.onPick,
    required this.onChanged,
  });
  final Customer? customer;
  final int pointsRedeemed;
  final int maxRedeemable;
  final VoidCallback onPick;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return OutlinedButton.icon(
        onPressed: onPick,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add customer'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.terracottaDark,
          side: const BorderSide(color: AppColors.terracotta),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
                child: Text(customer!.initials,
                    style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer!.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Balance ${customer!.loyaltyPoints} pts',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              TextButton(onPressed: onPick, child: const Text('Change')),
            ],
          ),
          if (maxRedeemable > 0) ...[
            const Divider(color: AppColors.border, height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Redeem $pointsRedeemed pts', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('−${formatVnd(pointsRedeemed * 100)} off total',
                          style: const TextStyle(color: AppColors.sageText, fontSize: 12)),
                    ],
                  ),
                ),
                _StepBtn(icon: Icons.remove, onTap: () => onChanged((pointsRedeemed - 100).clamp(0, maxRedeemable))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$pointsRedeemed', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                _StepBtn(icon: Icons.add, onTap: () => onChanged((pointsRedeemed + 100).clamp(0, maxRedeemable))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({required this.approved, required this.managerName, required this.onRequest});
  final bool approved;
  final String? managerName;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final color = approved ? AppColors.sageText : AppColors.terracottaDark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(approved ? Icons.verified_rounded : Icons.lock_outline_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(approved ? 'Approved by ${managerName ?? 'manager'}' : 'Manager approval required',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            approved
                ? 'Discount above 50% has been approved.'
                : 'Discounts above 50% of subtotal must be approved by a manager (BR-06).',
            style: TextStyle(color: color, fontSize: 12),
          ),
          if (!approved) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onRequest,
              style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size.fromHeight(44)),
              child: const Text('Request approval'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.subtotal,
    required this.discount,
    required this.method,
    required this.cashTendered,
    required this.amount,
  });
  final double subtotal;
  final double discount;
  final PaymentMethod method;
  final double cashTendered;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final change = (method == PaymentMethod.cash && cashTendered > amount) ? cashTendered - amount : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Subtotal', formatVnd(subtotal)),
          if (discount > 0) _row('Discount', '−${formatVnd(discount)}', accent: true),
          if (method == PaymentMethod.cash && cashTendered > 0) _row('Cash tendered', formatVnd(cashTendered)),
          if (change > 0) _row('Change due', formatVnd(change), bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: bold ? 15 : 14)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontSize: bold ? 16 : 14,
                color: accent ? AppColors.sageText : AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

// ---------------- customer picker ----------------
class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();
  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search customer…',
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
                error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
                data: (list) {
                  final filtered = _q.isEmpty
                      ? list
                      : list.where((c) => c.fullName.toLowerCase().contains(_q) || (c.phone ?? '').contains(_q)).toList();
                  return ListView(
                    controller: scroll,
                    children: filtered
                        .map((c) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
                                child: Text(c.initials,
                                    style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
                              ),
                              title: Text(c.fullName),
                              subtitle: Text('${c.loyaltyPoints} pts · ${c.phone ?? '—'}'),
                              onTap: () => Navigator.of(context).pop(c),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- manager approval dialog (Figma 13) ----------------
class _ManagerApprovalDialog extends ConsumerStatefulWidget {
  const _ManagerApprovalDialog();
  @override
  ConsumerState<_ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends ConsumerState<_ManagerApprovalDialog> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).verifyCredentials(_user.text, _pass.text);
      if (user.role != UserRole.manager && user.role != UserRole.administrator) {
        setState(() => _error = 'This account is not a manager.');
        return;
      }
      if (mounted) Navigator.of(context).pop(user);
    } catch (e) {
      setState(() => _error = 'Invalid credentials.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Manager approval'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _user, decoration: const InputDecoration(labelText: 'Manager username')),
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : const Text('Approve'),
        ),
      ],
    );
  }
}
