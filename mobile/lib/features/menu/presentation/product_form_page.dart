import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/ingredient_model.dart';
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
  final List<RecipeLine> _recipe = []; // BR-08
  bool _available = true;
  bool _saving = false;
  String? _serverError;
  File? _imageFile;
  String? _imageUrl;

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
    _imageUrl = p?.imageUrl;
    if (p?.size != null && p!.size!.isNotEmpty) {
      _sizes.addAll(p.size!.split('/').map((s) => s.trim()).where(_sizeOptions.contains));
    }
    if (p != null) _recipe.addAll(p.recipe);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
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

    setState(() => _saving = true);
    final repo = ref.read(menuRepositoryProvider);
    try {
      String? uploadedUrl = _imageUrl;
      if (_imageFile != null) {
        uploadedUrl = await repo.uploadProductImage(_imageFile!.path);
      }

      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'categoryId': _categoryId,
        'price': int.tryParse(_price.text.trim()) ?? 0,
        'size': _sizes.isEmpty ? null : (_sizeOptions.where(_sizes.contains).join('/')),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'isAvailable': _available,
        'imageUrl': uploadedUrl,
        'recipe': _recipe.map((r) => r.toJson()).toList(), // BR-08
      };

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
            const _Label('Product Image'),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_imageFile != null)
                        Image.file(
                          _imageFile!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else if (widget.product?.fullImageUrl != null)
                        Image.network(
                          widget.product!.fullImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.terracotta),
                            SizedBox(height: 8),
                            Text(
                              'Tap to select image',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (_imageFile != null || widget.product?.fullImageUrl != null)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                initialValue: _categoryId,
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('Ingredients per item'),
                TextButton.icon(
                  onPressed: _addRecipeLine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.terracottaDark),
                ),
              ],
            ),
            _RecipeEditor(
              recipe: _recipe,
              onEdit: _editRecipeLine,
              onRemove: (line) => setState(() => _recipe.remove(line)),
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
                activeThumbColor: AppColors.terracotta,
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
            if (_isEdit) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text('Delete product', style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Recipe (BR-08) ----------
  Future<void> _addRecipeLine() async {
    final ingredients = await ref.read(ingredientsProvider.future).catchError((e) {
      if (mounted) setState(() => _serverError = apiErrorMessage(e));
      return <Ingredient>[];
    });
    if (!mounted || ingredients.isEmpty) return;

    // Chỉ cho chọn nguyên liệu chưa có trong công thức (khóa chính là cặp product+ingredient).
    final used = _recipe.map((r) => r.ingredientId).toSet();
    final available = ingredients.where((i) => !used.contains(i.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All ingredients are already in this recipe.')),
      );
      return;
    }

    final result = await showDialog<RecipeLine>(
      context: context,
      builder: (_) => _RecipeLineDialog(ingredients: available),
    );
    if (result != null) setState(() => _recipe.add(result));
  }

  Future<void> _editRecipeLine(RecipeLine line) async {
    final result = await showDialog<RecipeLine>(
      context: context,
      builder: (_) => _RecipeLineDialog(existing: line),
    );
    if (result == null) return;
    setState(() {
      final i = _recipe.indexWhere((r) => r.ingredientId == line.ingredientId);
      if (i != -1) _recipe[i] = result;
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete product'),
        content: Text('Delete "${widget.product!.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuRepositoryProvider).deleteProduct(widget.product!.id);
      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // 409 nếu món đã từng vào order.
      if (mounted) setState(() => _serverError = apiErrorMessage(e));
    }
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

/// Danh sách nguyên liệu tiêu tốn cho 1 đơn vị món — xem/sửa/xóa (BR-08).
class _RecipeEditor extends StatelessWidget {
  const _RecipeEditor({required this.recipe, required this.onEdit, required this.onRemove});

  final List<RecipeLine> recipe;
  final ValueChanged<RecipeLine> onEdit;
  final ValueChanged<RecipeLine> onRemove;

  @override
  Widget build(BuildContext context) {
    if (recipe.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No ingredients yet. Stock will not be deducted for this product.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < recipe.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            ListTile(
              onTap: () => onEdit(recipe[i]),
              dense: true,
              title: Text(recipe[i].ingredientName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${recipe[i].quantityLabel} per item',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                onPressed: () => onRemove(recipe[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog thêm mới (chọn ingredient + lượng) hoặc sửa lượng của 1 dòng công thức.
class _RecipeLineDialog extends StatefulWidget {
  const _RecipeLineDialog({this.ingredients, this.existing});

  /// Danh sách nguyên liệu còn chọn được — chỉ dùng khi thêm mới.
  final List<Ingredient>? ingredients;

  /// Dòng đang sửa — khi có, ingredient đã cố định, chỉ sửa lượng.
  final RecipeLine? existing;

  @override
  State<_RecipeLineDialog> createState() => _RecipeLineDialogState();
}

class _RecipeLineDialogState extends State<_RecipeLineDialog> {
  late final TextEditingController _quantity;
  int? _ingredientId;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(text: widget.existing?.quantityLabel ?? '');
    _ingredientId = widget.existing?.ingredientId;
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (_ingredientId == null) {
      setState(() => _error = 'Please choose an ingredient.');
      return;
    }
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Quantity must be greater than 0.');
      return;
    }
    final name = _isEdit
        ? widget.existing!.ingredientName
        : widget.ingredients!.firstWhere((i) => i.id == _ingredientId).name;
    Navigator.pop(
      context,
      RecipeLine(ingredientId: _ingredientId!, ingredientName: name, quantity: qty),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_isEdit ? 'Edit ingredient' : 'Add ingredient'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit)
            Text(widget.existing!.ingredientName,
                style: const TextStyle(fontWeight: FontWeight.w600))
          else
            DropdownButtonFormField<int>(
              initialValue: _ingredientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ingredient'),
              items: widget.ingredients!
                  .map((i) => DropdownMenuItem(value: i.id, child: Text(i.name)))
                  .toList(),
              onChanged: (v) => setState(() => _ingredientId = v),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            autofocus: _isEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity per item',
              hintText: 'e.g. 18',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
