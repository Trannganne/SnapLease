/// Rental intervals are Vietnamese wall-clock values without an offset.
/// Hold deadlines are UTC; signing deadlines are Vietnamese local time.
class RentalTimeFormatter {
  // Backend RentalPolicy.LocalNow: Vietnam wall clock, not an interval shift.
  static DateTime vietnamNow() {
    final clock = DateTime.now().toUtc().add(const Duration(hours: 7));
    return DateTime(
      clock.year,
      clock.month,
      clock.day,
      clock.hour,
      clock.minute,
      clock.second,
    );
  }

  static String? periodError(DateTime? pickup, DateTime? dropoff) {
    if (pickup == null || dropoff == null) {
      return 'Vui lòng chọn đủ thời gian nhận và trả.';
    }
    if (!dropoff.isAfter(pickup)) {
      return 'Thời gian trả phải sau thời gian nhận.';
    }
    if (dropoff.difference(pickup) > const Duration(days: 90)) {
      return 'Thời gian thuê tối đa 90 ngày.';
    }
    if (!pickup.isAfter(vietnamNow())) {
      return 'Thời gian nhận phải ở tương lai.';
    }
    return null;
  }

  static String wallClock(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  static DateTime instant(String value, {bool vietnamLocal = false}) {
    final hasOffset = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return DateTime.parse(
      hasOffset ? value : '$value${vietnamLocal ? '+07:00' : 'Z'}',
    );
  }
}
