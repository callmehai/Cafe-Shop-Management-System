import 'package:flutter/foundation.dart';

class Env {
  // Cho phép override khi build: --dart-define=API_BASE_URL=http://192.168.x.x:3000/api
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL backend, tự chọn theo nền tảng:
  /// - Web / iOS simulator / desktop: localhost
  /// - Android emulator: 10.0.2.2 (alias trỏ về localhost máy host)
  /// - Thiết bị thật: truyền --dart-define=API_BASE_URL=http://<IP-máy>:3000/api
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }
}
