import 'dart:convert';
import 'package:intl/intl.dart';

/// Read-only presentation of an existing Backend appendix; never changes its status.
class ExtensionSummary {
  final String id;
  final String status;
  final DateTime? proposedReturn;
  final DateTime? signingDeadlineUtc;
  final String? reason;
  final num? fee;
  final DateTime? previousReturn;
  const ExtensionSummary({
    required this.id,
    required this.status,
    this.proposedReturn,
    this.signingDeadlineUtc,
    this.reason,
    this.fee,
    this.previousReturn,
  });

  factory ExtensionSummary.fromJson(Map<String, dynamic> row) {
    final deadline = DateTime.tryParse(row['hanKyUtc']?.toString() ?? '');
    return ExtensionSummary(
      previousReturn: DateTime.tryParse(row['hieuLucTu']?.toString() ?? ''),
      id: row['maPhuLuc']?.toString() ?? '',
      status: row['trangThai']?.toString() ?? '',
      proposedReturn: DateTime.tryParse(row['thoiHanTraMoi']?.toString() ?? ''),
      // UTC fields are explicitly UTC even when a legacy serializer omits Z.
      signingDeadlineUtc:
          deadline == null
              ? null
              : deadline.isUtc
              ? deadline
              : DateTime.utc(
                deadline.year,
                deadline.month,
                deadline.day,
                deadline.hour,
                deadline.minute,
                deadline.second,
                deadline.millisecond,
                deadline.microsecond,
              ),
      reason: (row['lyDoDong'] ?? row['ghiChu'])?.toString(),
      fee: row['chiPhiPhatSinh'] is num ? row['chiPhiPhatSinh'] as num : null,
    );
  }

  static Map<String, dynamic>? latestRow(List<Map<String, dynamic>> rows) {
    Map<String, dynamic>? latest;
    DateTime? latestDate;
    for (final row in rows) {
      final date = DateTime.tryParse(row['ngayLap']?.toString() ?? '');
      if (latest == null ||
          (date == null && latestDate == null) ||
          (date != null &&
              (latestDate == null || !date.isBefore(latestDate)))) {
        latest = row;
        latestDate = date;
      }
    }
    return latest;
  }

  String get label => switch (status) {
    'CHO_XAC_NHAN' => 'Gia hạn chờ duyệt',
    'CHO_KY' => 'Gia hạn được duyệt – Chờ ký phụ lục',
    'TU_CHOI' => 'Gia hạn bị từ chối',
    'DA_HIEU_LUC' => 'Gia hạn đã có hiệu lực',
    'DA_XAC_NHAN' => 'Gia hạn cũ đã xác nhận',
    'HET_HAN_KY' => 'Gia hạn hết hạn ký',
    'HET_HAN_XU_LY' => 'Gia hạn hết hạn xử lý',
    'DA_HUY' => 'Yêu cầu gia hạn đã hủy',
    'DONG_QUY_TRINH_CU' => 'Đã đóng yêu cầu theo quy trình cũ',
    _ => 'Trạng thái gia hạn chưa xác định',
  };

  bool canSignAt(DateTime serverUtc) =>
      status == 'CHO_KY' &&
      id.isNotEmpty &&
      signingDeadlineUtc != null &&
      serverUtc.toUtc().isBefore(signingDeadlineUtc!);

  String? get listMessage {
    if (status == 'DA_XAC_NHAN' || status == 'DA_HIEU_LUC') return null;
    final parts = <String>[label];
    if (proposedReturn != null) {
      parts.add(
        'Hạn đề nghị: ${DateFormat('dd/MM/yyyy HH:mm').format(proposedReturn!)}',
      );
    }
    if (status == 'CHO_KY' && signingDeadlineUtc != null) {
      parts.add(
        'Hạn ký: ${DateFormat('dd/MM/yyyy HH:mm').format(signingDeadlineUtc!.add(const Duration(hours: 7)))} (giờ Việt Nam)',
      );
    }
    if (status == 'TU_CHOI' && reason?.trim().isNotEmpty == true) {
      parts.add('Lý do: $reason');
    }
    return parts.join('\n');
  }
}

String appendixTermsText(Map<String, dynamic> appendix) {
  final raw = appendix['noiDungJson'];
  if (raw is! String) {
    throw const FormatException(
      'Phụ lục thiếu nội dung được Backend xác nhận.',
    );
  }
  final snapshot = jsonDecode(raw);
  final clauses = snapshot is Map ? snapshot['dieuKhoan'] : null;
  if (clauses is! List ||
      clauses.isEmpty ||
      clauses.any((c) => c is! String || c.trim().isEmpty)) {
    throw const FormatException(
      'Phụ lục thiếu điều khoản được Backend xác nhận.',
    );
  }
  return clauses.cast<String>().join('\n\n');
}

class ExtensionQuote {
  final bool available;
  final String? reason;
  final DateTime currentReturn;
  final DateTime newReturn;
  final int days;
  final num cost;
  const ExtensionQuote(
    this.available,
    this.reason,
    this.currentReturn,
    this.newReturn,
    this.days,
    this.cost,
  );

  factory ExtensionQuote.fromJson(Map<String, dynamic> json) => ExtensionQuote(
    json['coTheGiaHan'] as bool,
    json['lyDo'] as String?,
    DateTime.parse(json['thoiHanTraHienTai'] as String),
    DateTime.parse(json['thoiHanTraMoi'] as String),
    json['soNgayGiaHan'] as int,
    json['chiPhiDuKien'] as num,
  );
}

class ExtensionFailure implements Exception {
  final String message;
  final bool uncertain;
  const ExtensionFailure(this.message, {this.uncertain = false});
  @override
  String toString() => message;
}
