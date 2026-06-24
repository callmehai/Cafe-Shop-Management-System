import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../data/menu_repository.dart';
import '../domain/menu_models.dart';

/// Màn thêm/sửa sản phẩm (Figma "16 Product Details edit" + "17 validation").
class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.product});

  /// null = thêm mới; có giá trị = chỉnh sửa.
  final Product? product;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  static const _sizeOptions = ['S', 'M', 'L'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  int? _categoryId;
  final Set<String> _sizes = {};
  bool _available = true;
  bool _saving = false;
  String? _serverError;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _description = TextEditingController(text: p?.description ?? '');
    _categoryId = p?.categoryId;
    _available = p?.isAvailable ?? true;
    if (p?.size != null && p!.size!.isNotEmpty) {
      _sizes.addAll(p.size!.split('/').map((s) => s.trim()).where(_sizeOptions.contains));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _serverError = 'Please choose a category.');
      return;
    }

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'categoryId': _categoryId,
      'price': int.tryParse(_price.text.trim()) ?? 0,
      'size': _sizes.isEmpty ? null : (_sizeOptions.where(_sizes.contains).join('/')),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'isAvailable': _available,
    };

    setState(() => _saving = true);
    final repo = ref.read(menuRepositoryProvider);
    try {
      if (_isEdit) {
        await repo.updateProduct(widget.product!.id, body);
      } else {
        await repo.createProduct(body);
      }
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _serverError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _Label('Name'),
            TextFormField(
              controller: _name,
              maxLength: 30, // MSG02
              decoration: const InputDecoration(hintText: 'Cappuccino', counterText: ''),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'The Name field is required.';
                if (t.length > 30) return 'Exceed max length of 30.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Category'),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger)),
              data: (list) => DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(hintText: 'Choose category'),
                items: list
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
            ),
            const SizedBox(height: 16),
            const _Label('Price (₫)'),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '45000'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'The Price field is required.'; // MSG08
                final n = int.tryParse(t);
                if (n == null || n < 0) return 'Enter a valid price.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _Label('Sizes'),
            Wrap(
              spacing: 10,
              children: _sizeOptions.map((s) {
                final on = _sizes.contains(s);
                return ChoiceChip(
                  label: Text(s),
                  selected: on,
                  onSelected: (_) => setState(() => on ? _sizes.remove(s) : _sizes.add(s)),
                  selectedColor: AppColors.terracotta.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: on ? AppColors.terracottaDark : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: on ? AppColors.terracotta : AppColors.border),
                  ),
                  backgroundColor: AppColors.surface,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Description'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add a short description…'),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                activeColor: AppColors.terracotta,
                title: const Text('Available', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Show on order menu'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 14),
              Text(_serverError!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Save product'),
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
