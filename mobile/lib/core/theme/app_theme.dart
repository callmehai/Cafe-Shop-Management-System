import 'package:flutter/material.dart';

// Tông màu lấy từ mockup SRS (nâu cà phê + kem).
class AppTheme {
  static const _brown = Color(0xFFB5562B);
  static const _cream = Color(0xFFF5EFE6);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _brown, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(surface: _cream),
      scaffoldBackgroundColor: _cream,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52), // touch target lớn (usability §8)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
