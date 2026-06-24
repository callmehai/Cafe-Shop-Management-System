import '../../auth/domain/app_user.dart';

/// User do Admin quản lý (Figma "23 User Management" / "24 User Details").
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool isActive;

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
        id: json['id'] as int,
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        role: UserRole.fromApi(json['role'] as String? ?? ''),
        isActive: json['isActive'] as bool? ?? true,
      );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
