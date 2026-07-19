import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../order/data/orders_repository.dart';
import '../domain/payment_models.dart';

/// Màn thanh toán thành công (Figma "14 Payment success" — MSG04).
class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key, required this.result});
  final PaymentResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.sageText.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.sageText, size: 46),
              ),
              const SizedBox(height: 20),
              const Text('Payment completed successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Order #${result.orderNo} · ${result.methodLabel}',
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _Row(label: 'Total paid', value: formatVnd(result.amount), bold: true),
                    if (result.change > 0) _Row(label: 'Change', value: formatVnd(result.change)),
                    if (result.pointsRedeemed > 0)
                      _Row(label: 'Points redeemed', value: '−${result.pointsRedeemed} pts'),
                    if (result.pointsEarned > 0)
                      _Row(label: 'Points earned', value: '+${result.pointsEarned} pts', accent: true),
                    if (result.newBalance != null)
                      _Row(label: 'New balance', value: '${result.newBalance} pts'),
                  ],
                ),
              ),
              if (result.lowStock.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.terracottaDark, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Low stock: ${result.lowStock.join(', ')}',
                            style: const TextStyle(color: AppColors.terracottaDark, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  final orderId = int.tryParse(result.orderNo.replaceFirst('ORD-', '')) ?? 0;
                  final cleanOrderId = orderId > 1000 ? orderId - 1000 : orderId;
                  showDialog(
                    context: context,
                    builder: (ctx) => _ReceiptPreviewDialog(
                      orderId: cleanOrderId,
                      result: result,
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Print receipt'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.terracottaDark,
                  side: const BorderSide(color: AppColors.terracotta),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false, this.accent = false});
  final String label;
  final String value;
  final bool bold;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: bold ? 15 : 14)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontSize: bold ? 18 : 14,
                color: accent ? AppColors.sageText : AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}

class _ReceiptPreviewDialog extends ConsumerWidget {
  const _ReceiptPreviewDialog({required this.orderId, required this.result});
  final int orderId;
  final PaymentResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Receipt Preview', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            Flexible(
              child: orderAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Failed to load order details: ${apiErrorMessage(e)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                ),
                data: (order) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          color: Colors.black87,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                'CAFE SHOP MANAGEMENT',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                '123 Coffee Street, HCM\nTel: 090-123-4567',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                            Text('Order No: #${order.orderNo}'),
                            Text('Table: ${order.tableCode}'),
                            if (order.customerName != null) Text('Customer: ${order.customerName}'),
                            Text('Cashier: ${order.createdByName ?? 'Staff'}'),
                            const SizedBox(height: 8),
                            _dashedLine(),
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 44, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 70, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _dashedLine(),
                            const SizedBox(height: 8),
                            ...order.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName),
                                        if (item.options != null && item.options!.isNotEmpty)
                                          Text('  (${item.options})', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: Text('${item.quantity}', textAlign: TextAlign.right),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(formatVnd(item.linePrice), textAlign: TextAlign.right),
                                  ),
                                ],
                              ),
                            )),
                            const SizedBox(height: 8),
                            _dashedLine(),
                            const SizedBox(height: 8),
                            _receiptRow('Subtotal:', formatVnd(result.subtotal)),
                            if (result.discount > 0)
                              _receiptRow('Discount:', '-${formatVnd(result.discount)}'),
                            _dashedLine(),
                            const SizedBox(height: 4),
                            _receiptRow('TOTAL:', formatVnd(result.amount), bold: true),
                            _receiptRow('Payment Method:', result.methodLabel),
                            if (result.method == 'CASH') ...[
                              _receiptRow('Cash Tendered:', formatVnd(result.amount + result.change)),
                              _receiptRow('Change Due:', formatVnd(result.change)),
                            ],
                            const SizedBox(height: 8),
                            _dashedLine(),
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Thank you & See you again!\nCSMS v2.0',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                width: 200,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black45),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(40, (index) => Container(
                                    width: (index % 3 == 0) ? 4 : ((index % 5 == 0) ? 1 : 2),
                                    color: (index % 4 == 0) ? Colors.transparent : Colors.black,
                                  )),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(result.orderNo, style: const TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt printed successfully! (Mocked)')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _dashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontFamily: 'Courier',
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 13 : 12,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
