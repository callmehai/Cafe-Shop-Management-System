import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../data/inventory_repository.dart';
import '../domain/ingredient_model.dart';

class _Line {
  _Line();
  int? ingredientId;
  double quantity = 0;
  double unitCost = 0;
  double get total => quantity * unitCost;
}

/// Goods receipt / Stock-In (Figma "20 Purchase Order" + "21 Stock-In"). Cộng kho khi xác nhận.
class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({super.key});

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final _supplier = TextEditingController(text: 'Saigon Coffee Supply Co.');
  final List<_Line> _lines = [_Line()];
  bool _saving = false;

  double get _total => _lines.fold(0, (s, l) => s + l.total);

  @override
  void dispose() {
    _supplier.dispose();
    super.dispose();
  }

  Future<void> _confirm(List<Ingredient> ingredients) async {
    final valid = _lines.where((l) => l.ingredientId != null && l.quantity > 0).toList();
    if (_supplier.text.trim().isEmpty || valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add supplier and at least one line.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(inventoryRepositoryProvider).receiveStock(
            supplierName: _supplier.text.trim(),
            items: valid
                .map((l) => {'ingredientId': l.ingredientId, 'quantity': l.quantity, 'unitCost': l.unitCost})
                .toList(),
          );
      ref.invalidate(ingredientsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goods received · stock updated')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('Stock-In'),
      ),
      body: ingredientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
        error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
        data: (ingredients) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  const _Label('Supplier'),
                  TextField(controller: _supplier, decoration: const InputDecoration(hintText: 'Supplier name')),
                  const SizedBox(height: 16),
                  const _Label('Items'),
                  ..._lines.asMap().entries.map((e) => _LineCard(
                        line: e.value,
                        ingredients: ingredients,
                        onChanged: () => setState(() {}),
                        onRemove: _lines.length > 1 ? () => setState(() => _lines.removeAt(e.key)) : null,
                      )),
                  TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_Line())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add line item'),
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
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      Text(formatVnd(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : () => _confirm(ingredients),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text('Confirm goods receipt'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.ingredients, required this.onChanged, this.onRemove});
  final _Line line;
  final List<Ingredient> ingredients;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: line.ingredientId,
                  isExpanded: true,
                  decoration: const InputDecoration(hintText: 'Ingredient', isDense: true),
                  items: ingredients.map((i) => DropdownMenuItem(value: i.id, child: Text(i.name))).toList(),
                  onChanged: (v) {
                    line.ingredientId = v;
                    onChanged();
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: onRemove),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.quantity == 0 ? '' : line.quantity.toString(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                  onChanged: (v) {
                    line.quantity = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: line.unitCost == 0 ? '' : line.unitCost.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Unit cost ₫', isDense: true),
                  onChanged: (v) {
                    line.unitCost = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          if (line.total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(formatVnd(line.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}
