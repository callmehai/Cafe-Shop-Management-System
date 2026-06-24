/// Vai trò người dùng — đồng bộ với enum Role ở backend (Prisma).
enum UserRole {
  administrator,
  manager,
  cashier,
  barista,
  unknown;

  static UserRole fromApi(String raw) {
    switch (raw.toUpperCase()) {
      case 'ADMINISTRATOR':
        return UserRole.administrator;
      case 'MANAGER':
        return UserRole.manager;
      case 'CASHIER':
        return UserRole.cashier;
      case 'BARISTA':
        return UserRole.barista;
      default:
        return UserRole.unknown;
    }
  }

  /// Giá trị gửi/khớp với backend.
  String get api => switch (this) {
        UserRole.administrator => 'ADMINISTRATOR',
        UserRole.manager => 'MANAGER',
        UserRole.cashier => 'CASHIER',
        UserRole.barista => 'BARISTA',
        UserRole.unknown => 'UNKNOWN',
      };

  /// Nhãn hiển thị (pill trên dashboard).
  String get label => switch (this) {
        UserRole.administrator => 'Administrator',
        UserRole.manager => 'Manager',
        UserRole.cashier => 'Cashier',
        UserRole.barista => 'Barista',
        UserRole.unknown => 'User',
      };
}

/// Hồ sơ người dùng đăng nhập.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        role: UserRole.fromApi(json['role'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'role': role.api,
      };

  /// Chữ cái viết tắt cho avatar (vd "Linh Nguyen" -> "LN").
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
