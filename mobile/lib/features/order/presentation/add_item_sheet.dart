import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../menu/domain/menu_models.dart';

/// Kết quả chọn món từ sheet.
class AddItemResult {
  const AddItemResult({required this.quantity, this.options});
  final int quantity;
  final String? options;
}

/// Mở bottom sheet chọn size/sugar/notes/quantity (Figma "09 Add item sheet").
/// [initial] != null khi đang sửa một dòng món.
Future<AddItemResult?> showAddItemSheet(
  BuildContext context,
  Product product, {
  AddItemResult? initial,
}) {
  return showModalBottomSheet<AddItemResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AddItemSheet(product: product, initial: initial),
  );
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.product, this.initial});
  final Product product;
  final AddItemResult? initial;

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  static const _sugarLevels = ['0%', '30%', '50%', '100%'];

  late List<String> _sizes;
  String? _size;
  String? _sugar;
  final _notes = TextEditingController();
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _sizes = (widget.product.size ?? '')
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    _size = _sizes.isNotEmpty ? _sizes.first : null;
    // parse lại từ options cũ nếu đang sửa
    final opt = widget.initial?.options;
    if (opt != null) {
      for (final s in _sizes) {
        if (opt.startsWith('$s ') || opt == s) _size = s;
      }
      final sugarMatch = RegExp(r'Sugar (\d+%)').firstMatch(opt);
      if (sugarMatch != null) _sugar = sugarMatch.group(1);
    }
    _qty = widget.initial?.quantity ?? 1;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String? _buildOptions() {
    final parts = <String>[];
    if (_size != null) parts.add(_size!);
    if (_sugar != null && _sugar != '0%') parts.add('Sugar $_sugar');
    if (_notes.text.trim().isNotEmpty) parts.add(_notes.text.trim());
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.product.price * _qty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(formatVnd(widget.product.price), style: const TextStyle(color: AppColors.textMuted)),
            if (_sizes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const _Label('Size'),
              _Chips(options: _sizes, selected: _size, onTap: (s) => setState(() => _size = s)),
            ],
            const SizedBox(height: 16),
            const _Label('Sugar level'),
            _Chips(options: _sugarLevels, selected: _sugar ?? '0%', onTap: (s) => setState(() => _sugar = s)),
            const SizedBox(height: 16),
            const _Label('Notes'),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(hintText: 'e.g. extra hot, oat milk…'),
            ),
            const SizedBox(height: 16),
            const _Label('Quantity'),
            Row(
              children: [
                _StepBtn(icon: Icons.remove, onTap: () => setState(() => _qty = (_qty - 1).clamp(1, 99))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('$_qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                _StepBtn(icon: Icons.add, onTap: () => setState(() => _qty = (_qty + 1).clamp(1, 99))),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(AddItemResult(quantity: _qty, options: _buildOptions())),
              child: Text('${widget.initial == null ? 'Add' : 'Update'} $_qty · ${formatVnd(total)}'),
            ),
          ],
        ),
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
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onTap});
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        final on = o == selected;
        return ChoiceChip(
          label: Text(o),
          selected: on,
          onSelected: (_) => onTap(o),
          selectedColor: AppColors.terracotta.withValues(alpha: 0.18),
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: on ? AppColors.terracottaDark : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: on ? AppColors.terracotta : AppColors.border),
          ),
        );
      }).toList(),
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
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: AppColors.terracottaDark)),
      ),
    );
  }
}
