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
