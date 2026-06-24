class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.loyaltyPoints,
    this.phone,
    this.email,
  });

  final int id;
  final String fullName;
  final int loyaltyPoints;
  final String? phone;
  final String? email;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// 1 dòng lịch sử điểm (màn 27).
class LoyaltyActivity {
  const LoyaltyActivity({required this.type, required this.points, this.orderNo, this.amount});
  final String type; // EARN / REDEEM
  final int points;
  final String? orderNo;
  final double? amount;

  factory LoyaltyActivity.fromJson(Map<String, dynamic> json) => LoyaltyActivity(
        type: json['type'] as String? ?? 'EARN',
        points: json['points'] as int? ?? 0,
        orderNo: json['orderNo'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
      );

  bool get isEarn => type.toUpperCase() == 'EARN';
}

/// Khách + lịch sử điểm (detail).
class CustomerDetail extends Customer {
  const CustomerDetail({
    required super.id,
    required super.fullName,
    required super.loyaltyPoints,
    super.phone,
    super.email,
    required this.activity,
  });

  final List<LoyaltyActivity> activity;

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        activity: (json['activity'] as List? ?? [])
            .map((e) => LoyaltyActivity.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
