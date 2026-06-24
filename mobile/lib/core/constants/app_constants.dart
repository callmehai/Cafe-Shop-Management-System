class AppConstants {
  static const inactivityTimeout = Duration(minutes: 30); // CR-12 auto-logout
  static const tokenKey = 'csms_access_token';
}

// Đồng bộ với enum Role backend.
enum Role { administrator, manager, cashier, barista }
