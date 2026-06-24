import 'dart:ui';
import '../../../core/theme/app_colors.dart';

/// Trạng thái chiếm dụng bàn — đồng bộ enum OccupancyStatus ở backend.
enum TableStatus {
  free,
  occupied,
  reserved;

  static TableStatus fromApi(String raw) => switch (raw.toUpperCase()) {
        'OCCUPIED' => TableStatus.occupied,
        'RESERVED' => TableStatus.reserved,
        _ => TableStatus.free,
      };

  String get api => switch (this) {
        TableStatus.free => 'FREE',
        TableStatus.occupied => 'OCCUPIED',
        TableStatus.reserved => 'RESERVED',
      };

  /// Nhãn ngắn trên thẻ bàn (khớp Figma: Free / Busy / Resv).
  String get shortLabel => switch (this) {
        TableStatus.free => 'Free',
        TableStatus.occupied => 'Busy',
        TableStatus.reserved => 'Resv',
      };

  Color get color => switch (this) {
        TableStatus.free => AppColors.sageText,
        TableStatus.occupied => AppColors.terracotta,
        TableStatus.reserved => AppColors.espresso,
      };
}

class TableModel {
  const TableModel({
    required this.id,
    required this.number,
    required this.capacity,
    required this.status,
    this.floor,
    this.shape,
  });

  final int id;
  final int number;
  final int capacity;
  final TableStatus status;
  final String? floor; // zone
  final String? shape;

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        id: json['id'] as int,
        number: json['number'] as int,
        capacity: json['capacity'] as int,
        status: TableStatus.fromApi(json['occupancyStatus'] as String? ?? 'FREE'),
        floor: json['floor'] as String?,
        shape: json['shape'] as String?,
      );

  String get zone => floor ?? 'Unzoned';

  /// Mã hiển thị: T-05 (Main floor) / P-05 (Terrace) — suy từ zone.
  String get code {
    final prefix = (floor ?? 'T').trim().isNotEmpty ? (floor ?? 'T')[0].toUpperCase() : 'T';
    return '$prefix-${number.toString().padLeft(2, '0')}';
  }
}
