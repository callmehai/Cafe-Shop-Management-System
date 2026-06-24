class Env {
  // Đổi sang IP máy chạy backend khi test trên thiết bị thật.
  // Android emulator dùng 10.0.2.2 để trỏ về localhost máy host.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000/api');
}
