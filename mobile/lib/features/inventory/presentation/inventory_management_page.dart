import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/inventory_repository.dart';
import '../domain/ingredient_model.dart';
import 'stock_in_page.dart';

/// Quản lý kho (Figma "19 Inventory"). Low-stock lên đầu, nút Receive (Stock-In).
class InventoryManagementPage extends ConsumerWidget {
  const InventoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(ingredientsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockInPage()));
          ref.invalidate(ingredientsProvider);
        },
        icon: const Icon(Icons.download_rounded),
        label: const Text('Receive'),
      ),
      body: SafeArea(
        bottom: false,
        child: ingredients.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
          error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
          data: (list) {
            final low = list.where((i) => i.lowStock).toList();
            final ok = list.where((i) => !i.lowStock).toList();
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(ingredientsProvider),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  PageHeader(
                    title: 'Inventory',
                    subtitle: '${low.length} of ${list.length} low on stock',
                    trailing: IconButton(
                      icon: const Icon(Icons.add, color: AppColors.terracotta),
                      onPressed: () => _ingredientDialog(context, ref),
                    ),
                  ),
                  if (low.isNotEmpty) ...[
                    const _SectionTitle('Low stock — reorder soon'),
                    ...low.map((i) => _IngredientRow(ingredient: i, onTap: () => _ingredientDialog(context, ref, ingredient: i))),
                  ],
                  if (ok.isNotEmpty) ...[
                    const _SectionTitle('In stock'),
                    ...ok.map((i) => _IngredientRow(ingredient: i, onTap: () => _ingredientDialog(context, ref, ingredient: i))),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _ingredientDialog(BuildContext context, WidgetRef ref, {Ingredient? ingredient}) async {
    final name = TextEditingController(text: ingredient?.name ?? '');
    final qoh = TextEditingController(text: ingredient != null ? Ingredient.stockNum(ingredient.quantityOnHand) : '');
    final thr = TextEditingController(text: ingredient != null ? Ingredient.stockNum(ingredient.reorderThreshold) : '');
    final isEdit = ingredient != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEdit ? 'Edit ingredient' : 'Add ingredient'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(
              controller: qoh,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Quantity on hand'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: thr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Reorder threshold'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final body = {
                'name': name.text.trim(),
                'quantityOnHand': double.tryParse(qoh.text.trim()) ?? 0,
                'reorderThreshold': double.tryParse(thr.text.trim()) ?? 0,
              };
              try {
                final repo = ref.read(inventoryRepositoryProvider);
                if (isEdit) {
                  await repo.updateIngredient(ingredient.id, body);
                } else {
                  await repo.createIngredient(body);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) ref.invalidate(ingredientsProvider);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.onTap});
  final Ingredient ingredient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final low = ingredient.lowStock;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: low ? AppColors.terracotta.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
            color: low ? AppColors.terracottaDark : AppColors.textMuted),
        title: Text(ingredient.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          ingredient.stockLine,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: low ? AppColors.terracottaDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
