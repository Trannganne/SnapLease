/// Cancellation metadata is evidence only after the contract itself is DA_HUY.
class ContractCancellationSummary {
  final DateTime? effectiveAtUtc;
  final DateTime? requestedAtUtc;
  final String? requestReason;
  final String? processingReason;

  const ContractCancellationSummary({
    this.effectiveAtUtc,
    this.requestedAtUtc,
    this.requestReason,
    this.processingReason,
  });

  static ContractCancellationSummary? fromApprovedRequests(
    List<Map<String, dynamic>> rows,
  ) {
    ContractCancellationSummary? latest;
    for (final row in rows.where((r) => r['trangThai'] == 'DA_DUYET')) {
      final item = ContractCancellationSummary(
        effectiveAtUtc: _utcDate(row['xuLyLucUtc']),
        requestedAtUtc: _utcDate(row['yeuCauLucUtc']),
        requestReason: _text(row['lyDo']),
        processingReason: _text(row['lyDoXuLy']),
      );
      if (latest == null ||
          (item.effectiveAtUtc != null &&
              (latest.effectiveAtUtc == null ||
                  item.effectiveAtUtc!.isAfter(latest.effectiveAtUtc!)))) {
        latest = item;
      }
    }
    return latest;
  }

  static String? _text(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _utcDate(dynamic value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null || date.isUtc) return date;
    // These API fields are UTC, including serializers which omit the Z suffix.
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
