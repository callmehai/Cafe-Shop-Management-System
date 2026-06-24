import '../../../core/utils/format.dart';

enum PaymentMethod {
  cash,
  card,
  eWallet;

  String get api => switch (this) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.card => 'CARD',
        PaymentMethod.eWallet => 'E_WALLET',
      };

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.eWallet => 'E-Wallet',
      };
}

/// Kết quả thanh toán trả về từ backend (màn 14 Success).
class PaymentResult {
  const PaymentResult({
    required this.orderNo,
    required this.method,
    required this.subtotal,
    required this.discount,
    required this.amount,
    required this.change,
    required this.pointsRedeemed,
    required this.pointsEarned,
    required this.lowStock,
    this.newBalance,
  });

  final String orderNo;
  final String method;
  final double subtotal;
  final double discount;
  final double amount;
  final double change;
  final int pointsRedeemed;
  final int pointsEarned;
  final int? newBalance;
  final List<String> lowStock;

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final p = json['payment'];
    return PaymentResult(
      orderNo: json['orderNo'] as String? ?? '',
      method: p is Map ? (p['method'] as String? ?? 'CASH') : 'CASH',
      subtotal: parseAmount(json['subtotal']),
      discount: parseAmount(json['discount']),
      amount: parseAmount(json['amount']),
      change: parseAmount(json['change']),
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      newBalance: json['newBalance'] as int?,
      lowStock: (json['lowStock'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }

  String get methodLabel => switch (method) {
        'CASH' => 'Cash',
        'CARD' => 'Card',
        'E_WALLET' => 'E-Wallet',
        _ => method,
      };

  String get amountLabel => formatVnd(amount);
}
