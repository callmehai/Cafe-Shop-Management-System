import '../../../core/config/env.dart';
import '../../../core/utils/format.dart';

/// Danh mục món (Category) kèm số sản phẩm.
class Category {
  const Category({required this.id, required this.name, required this.productCount});

  final int id;
  final String name;
  final int productCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      productCount: count is Map ? (count['products'] as int? ?? 0) : 0,
    );
  }
}

/// 1 dòng công thức (BR-08): lượng nguyên liệu cần cho 1 đơn vị sản phẩm.
class RecipeLine {
  const RecipeLine({
    required this.ingredientId,
    required this.ingredientName,
    required this.quantity,
  });

  final int ingredientId;
  final String ingredientName;
  final double quantity;

  factory RecipeLine.fromJson(Map<String, dynamic> json) {
    final ing = json['ingredient'];
    return RecipeLine(
      ingredientId: json['ingredientId'] as int,
      ingredientName: ing is Map ? (ing['name'] as String? ?? '') : '',
      quantity: parseAmount(json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => {'ingredientId': ingredientId, 'quantity': quantity};

  /// "120" hoặc "0.5" — bỏ phần thập phân thừa.
  String get quantityLabel =>
      quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toString();

  RecipeLine copyWith({double? quantity}) => RecipeLine(
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        quantity: quantity ?? this.quantity,
      );
}

/// Sản phẩm (Product) trong menu.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.isAvailable,
    this.size,
    this.description,
    this.imageUrl,
    this.recipe = const [],
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final double price;
  final bool isAvailable;
  final String? size;
  final String? description;
  final String? imageUrl;

  /// Nguyên liệu tiêu tốn cho 1 đơn vị món (BR-08).
  final List<RecipeLine> recipe;

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['category'];
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['categoryId'] as int,
      categoryName: cat is Map ? (cat['name'] as String? ?? '') : '',
      price: parseAmount(json['price']),
      isAvailable: json['isAvailable'] as bool? ?? true,
      size: json['size'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      recipe: (json['recipe'] as List? ?? [])
          .map((e) => RecipeLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Trả về đường dẫn ảnh đầy đủ (tự động ghép với base URL của server nếu là đường dẫn tương đối)
  String? get fullImageUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) {
      return imageUrl;
    }
    final base = Env.apiBaseUrl.replaceAll('/api', '');
    return '$base$imageUrl';
  }

  /// Dòng phụ dưới tên: "45,000₫ · S/M/L" hoặc "45,000₫ · out of stock".
  String get priceLine {
    final base = formatVnd(price);
    if (!isAvailable) return '$base · out of stock';
    if (size != null && size!.isNotEmpty) return '$base · $size';
    return base;
  }
}
