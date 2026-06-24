import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../data/customers_repository.dart';
import '../domain/customer_model.dart';
import 'customer_form_page.dart';

/// Chi tiết khách + lịch sử điểm (Figma "27 Customer Details").
class CustomerDetailsPage extends ConsumerWidget {
  const CustomerDetailsPage({super.key, required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDetailProvider(customerId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Customer'),
        actions: [
          detail.maybeWhen(
            data: (c) => IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.terracotta),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => CustomerFormPage(customer: c)),
                );
                ref.invalidate(customerDetailProvider(customerId));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
                  child: Text(c.initials,
                      style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text([c.phone, c.email].where((e) => e != null && e.isNotEmpty).join(' · '),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loyalty points', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('${c.loyaltyPoints}',
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Loyalty activity', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (c.activity.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No activity yet.', style: TextStyle(color: AppColors.textMuted))),
              )
            else
              ...c.activity.map((a) => _ActivityRow(activity: a)),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final LoyaltyActivity activity;

  @override
  Widget build(BuildContext context) {
    final earn = activity.isEarn;
    final color = earn ? AppColors.sageText : AppColors.terracottaDark;
    final sub = activity.orderNo != null
        ? '#${activity.orderNo}${activity.amount != null ? ' · ${formatVnd(activity.amount!)}' : ''}'
        : (earn ? 'Earned' : 'Redeemed');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(earn ? 'Earn' : 'Redeem', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.textMuted))),
          Text('${earn ? '+' : '−'}${activity.points}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
