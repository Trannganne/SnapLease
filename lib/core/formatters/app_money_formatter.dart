import 'package:intl/intl.dart';

/// Preserve Backend decimal amounts while keeping existing whole-VND presentation.
class AppMoneyFormatter {
  const AppMoneyFormatter();
  String format(num? value) {
    if (value == null || !value.isFinite) return 'Chưa xác định';
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
  }
}
