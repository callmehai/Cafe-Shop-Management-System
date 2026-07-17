import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/menu_repository.dart';
import '../domain/menu_models.dart';
import 'product_form_page.dart';

/// Màn quản lý menu — tab Products (15) + Categories (18). Role Manager/Admin.
class MenuManagementPage extends ConsumerWidget {
  const MenuManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);

    final productCount = products.valueOrNull?.length ?? 0;
    final categoryCount = categories.valueOrNull?.length ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PageHeader(
                title: 'Menu',
                subtitle: '$productCount products · $categoryCount categories',
              ),
              const TabBar(
                labelColor: AppColors.terracotta,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.terracotta,
                labelStyle: TextStyle(fontWeight: FontWeight.w700),
                tabs: [Tab(text: 'Products'), Tab(text: 'Categories')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ProductsTab(products: products),
                    _CategoriesTab(categories: categories),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- PRODUCTS TAB -----------------------------
class _ProductsTab extends ConsumerStatefulWidget {
  const _ProductsTab({required this.products});
  final AsyncValue<List<Product>> products;

  @override
  ConsumerState<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends ConsumerState<_ProductsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search products…',
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: widget.products.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
                error: (e, _) => _ErrorView(message: apiErrorMessage(e), onRetry: () => ref.invalidate(productsProvider)),
                data: (all) {
                  final list = _query.isEmpty
                      ? all
                      : all.where((p) => p.name.toLowerCase().contains(_query)).toList();
                  if (list.isEmpty) {
                    return const _EmptyView(text: 'No products found.');
                  }
                  final grouped = <String, List<Product>>{};
                  for (final p in list) {
                    grouped.putIfAbsent(p.categoryName, () => []).add(p);
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(productsProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      children: grouped.entries.expand((entry) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 8),
                            child: Text(
                              entry.key.isEmpty ? 'Uncategorized' : entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          ...entry.value.map((p) => _ProductRow(
                                product: p,
                                onTap: () => _openForm(context, product: p),
                              )),
                        ];
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'menu-fab',
            backgroundColor: AppColors.terracotta,
            foregroundColor: Colors.white,
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, {Product? product}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormPage(product: product)),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  Widget _fallbackLetter() {
    return Center(
      child: Text(
        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
        style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700, fontSize: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.terracotta.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: product.fullImageUrl != null
                ? Image.network(
                    product.fullImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fallbackLetter(),
                  )
                : _fallbackLetter(),
          ),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          product.priceLine,
          style: TextStyle(
            color: product.isAvailable ? AppColors.textMuted : AppColors.danger,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}

// ----------------------------- CATEGORIES TAB -----------------------------
class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.categories});
  final AsyncValue<List<Category>> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
      error: (e, _) => _ErrorView(message: apiErrorMessage(e), onRetry: () => ref.invalidate(categoriesProvider)),
      data: (list) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoriesProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ...list.map((c) => _CategoryRow(
                  category: c,
                  onEdit: () => _categoryDialog(context, ref, category: c),
                  onDelete: () => _confirmDelete(context, ref, c),
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _categoryDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppColors.terracottaDark,
                side: const BorderSide(color: AppColors.terracotta),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _categoryDialog(BuildContext context, WidgetRef ref, {Category? category}) async {
    final controller = TextEditingController(text: category?.name ?? '');
    final isEdit = category != null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: 'Category name', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                final repo = ref.read(menuRepositoryProvider);
                if (isEdit) {
                  await repo.updateCategory(category.id, name);
                } else {
                  await repo.createCategory(name);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      ref.invalidate(categoriesProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete category'),
        content: Text('Are you sure you want to delete "${c.name}"?'),
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
      await ref.read(menuRepositoryProvider).deleteCategory(c.id);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onEdit, required this.onDelete});
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onEdit,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${category.productCount} products',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// ----------------------------- shared small views -----------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(text, style: const TextStyle(color: AppColors.textMuted)));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
