class AppConstants {
  static const inactivityTimeout = Duration(minutes: 30); // CR-12 auto-logout

  // Khóa lưu trong secure storage.
  static const tokenKey = 'csms_access_token';
  static const userKey = 'csms_user'; // cache hồ sơ user (JSON) để mở app nhanh

  static const storeLabel = 'Store #HCM-01';
  static const appVersionLabel = 'CSMS v2.0';
}
