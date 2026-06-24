import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/page_header.dart';
import '../data/reports_repository.dart';

final _rangeProvider = StateProvider.autoDispose<String>((ref) => '7d');

/// Báo cáo doanh thu (Figma "22 Reports"). Range Today / 7 days / 30 days.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  static const _ranges = {'today': 'Today', '7d': '7 days', '30d': '30 days'};

  // UC21: lấy CSV và copy vào clipboard (hoạt động cả trên web).
  Future<void> _export(BuildContext context, WidgetRef ref, String range) async {
    try {
      final csv = await ref.read(reportsRepositoryProvider).exportCsv(range);
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report CSV copied to clipboard')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(_rangeProvider);
    final report = ref.watch(salesReportProvider(range));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Reports',
              subtitle: 'Sales & revenue',
              trailing: TextButton.icon(
                onPressed: () => _export(context, ref, range),
                icon: const Icon(Icons.ios_share, size: 18, color: AppColors.terracotta),
                label: const Text('Export', style: TextStyle(color: AppColors.terracottaDark)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _ranges.entries.map((e) {
                  final on = e.key == range;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: SizedBox(width: double.infinity, child: Text(e.value, textAlign: TextAlign.center)),
                        selected: on,
                        onSelected: (_) => ref.read(_rangeProvider.notifier).state = e.key,
                        selectedColor: AppColors.espresso,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(color: on ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: on ? AppColors.espresso : AppColors.border),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            report.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
              ),
              data: (r) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Revenue · ${_ranges[range]}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(formatVnd(r.totalRevenue),
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _StatTile(value: '${r.orderCount}', label: 'Orders')),
                        const SizedBox(width: 14),
                        Expanded(child: _StatTile(value: formatVnd(r.avgTicket), label: 'Avg ticket')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(alignment: Alignment.centerLeft, child: Text('Top products', style: TextStyle(fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(height: 8),
                  if (r.topProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No sales in this range.', style: TextStyle(color: AppColors.textMuted))),
                    )
                  else
                    ...r.topProducts.map((p) => Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              Text('${p.qty}×', style: const TextStyle(color: AppColors.textMuted)),
                              const SizedBox(width: 16),
                              Text(p.revenueLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
