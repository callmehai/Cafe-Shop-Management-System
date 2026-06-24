import 'package:intl/intl.dart';

final NumberFormat _vnd = NumberFormat.decimalPattern('en_US');

/// Format tiền VND: 45000 -> "45,000₫" (CR-02).
String formatVnd(num value) => '${_vnd.format(value)}₫';

/// Parse số tiền từ Decimal (backend trả về dạng String) hoặc num.
double parseAmount(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw) ?? 0;
  return 0;
}
