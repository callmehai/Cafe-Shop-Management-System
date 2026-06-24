import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../tables/data/tables_repository.dart';
import '../../tables/domain/table_model.dart';

/// Chọn bàn cho order (Figma "08A Assign Table" — floor map). Chỉ bàn FREE chọn được.
class TablePickerPage extends ConsumerWidget {
  const TablePickerPage({super.key, this.orderNo});
  final String? orderNo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Assign Table'),
      ),
      body: tables.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
        data: (list) {
          final zones = <String, List<TableModel>>{};
          for (final t in list) {
            zones.putIfAbsent(t.zone, () => []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const _Legend(),
              for (final entry in zones.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
                  child: Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: entry.value.map((t) {
                    final free = t.status == TableStatus.free;
                    return _TableCell(
                      table: t,
                      enabled: free,
                      onTap: free ? () => Navigator.of(context).pop(t) : null,
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          dot(AppColors.sageText, 'Free'),
          dot(AppColors.terracotta, 'Occupied'),
          dot(AppColors.espresso, 'Reserved'),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.table, required this.enabled, this.onTap});
  final TableModel table;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: table.status.color.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(table.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text('${table.capacity} seats', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(table.status.shortLabel,
                    style: TextStyle(fontSize: 11, color: table.status.color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
