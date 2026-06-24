import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
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
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt printing — not wired in this build')),
                ),
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
