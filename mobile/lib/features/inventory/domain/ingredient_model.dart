import '../../../core/utils/format.dart';

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.quantityOnHand,
    required this.reorderThreshold,
    required this.lowStock,
  });

  final int id;
  final String name;
  final double quantityOnHand;
  final double reorderThreshold;
  final bool lowStock;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final qoh = parseAmount(json['quantityOnHand']);
    final thr = parseAmount(json['reorderThreshold']);
    return Ingredient(
      id: json['id'] as int,
      name: json['name'] as String,
      quantityOnHand: qoh,
      reorderThreshold: thr,
      lowStock: json['lowStock'] as bool? ?? (qoh <= thr),
    );
  }

  /// "4 / 20" — tồn hiện tại trên ngưỡng đặt lại.
  String get stockLine => '${stockNum(quantityOnHand)} / ${stockNum(reorderThreshold)}';

  static String stockNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
