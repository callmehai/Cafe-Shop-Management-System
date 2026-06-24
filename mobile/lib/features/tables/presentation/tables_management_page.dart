import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/tables_repository.dart';
import '../domain/table_model.dart';
import 'table_form_page.dart';

/// Quản lý bàn (Figma "28 Table Management"). Nhóm theo zone, thẻ hiển thị trạng thái.
class TablesManagementPage extends ConsumerWidget {
  const TablesManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add table'),
      ),
      body: SafeArea(
        bottom: false,
        child: tables.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(tablesProvider), child: const Text('Retry')),
              ],
            ),
          ),
          data: (list) {
            final zones = <String, List<TableModel>>{};
            for (final t in list) {
              zones.putIfAbsent(t.zone, () => []).add(t);
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(tablesProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  PageHeader(
                    title: 'Tables',
                    subtitle: '${list.length} tables · ${zones.length} zones',
                  ),
                  for (final entry in zones.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Row(
                        children: [
                          Text(entry.key,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('${entry.value.length}',
                              style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: entry.value
                            .map((t) => _TableCard(table: t, onTap: () => _openForm(context, table: t)))
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {TableModel? table}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TableFormPage(table: table)),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.onTap});
  final TableModel table;
  final VoidCallback onTap;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(table.code,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  _StatusPill(status: table.status),
                ],
              ),
              const Spacer(),
              Text('${table.capacity} seats',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              if (table.shape != null)
                Text(table.shape!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TableStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.shortLabel,
        style: TextStyle(color: status.color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
