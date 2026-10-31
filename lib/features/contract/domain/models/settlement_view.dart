/// Server-authoritative settlement. Missing money remains unknown.
class SettlementView {
  final String contractId;
  final String contractStatus;
  final String status;
  final String? hash;
  final Map<String, dynamic>? receipt;
  final List<Map<String, dynamic>> charges;
  final List<Map<String, dynamic>> allocations;
  final List<Map<String, dynamic>> sources;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> feedback;
  final List<String> blockers;
  final Map<String, dynamic> actions;
  final num? total;
  final num? paidRental;
  final num? deposit;
  final num? depositUsed;
  final num? collectionRemaining;
  final num? refundEntitlement;
  final num? refundRecorded;
  final num? refundRemaining;
  final bool gatewayReady;
  final bool stale;
  final List<String> reviewEligibleIds;

  const SettlementView({
    required this.contractId,
    required this.contractStatus,
    required this.status,
    required this.hash,
    required this.receipt,
    required this.charges,
    required this.allocations,
    required this.sources,
    required this.payments,
    required this.feedback,
    required this.blockers,
    required this.actions,
    this.total,
    this.paidRental,
    this.deposit,
    this.depositUsed,
    this.collectionRemaining,
    this.refundEntitlement,
    this.refundRecorded,
    this.refundRemaining,
    this.gatewayReady = false,
    this.stale = false,
    this.reviewEligibleIds = const [],
  });

  factory SettlementView.fromJson(
    Map<String, dynamic> json,
    String requestedId,
  ) {
    if (json['maHopDong'] != requestedId ||
        !const [2, 3].contains(json['schemaVersion']) ||
        json['trangThaiQuyetToan'] is! String ||
        json['trangThaiHopDong'] is! String) {
      throw const FormatException(
        'Chưa có dữ liệu quyết toán hợp lệ của hợp đồng.',
      );
    }
    num? money(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Số tiền quyết toán không hợp lệ.');
      }
      return value;
    }

    final hash = json['maBamQuyetToan'] as String?;
    if (hash != null && !RegExp(r'^[A-Fa-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Mã băm quyết toán không hợp lệ.');
    }
    if (json['trangThaiQuyetToan'] == 'DA_CHOT' &&
        (hash == null ||
            json['phienBan'] != 1 ||
            json['maQuyetToan'] is! String ||
            (json['maQuyetToan'] as String).isEmpty)) {
      throw const FormatException('Thiếu bản quyết toán đã chốt.');
    }
    List<Map<String, dynamic>> rows(String key) {
      final value = json[key];
      if (value == null) return [];
      if (value is! List || value.any((row) => row is! Map)) {
        throw const FormatException('Chi tiết quyết toán không hợp lệ.');
      }
      final result =
          value.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      for (final row in result) {
        if (row['maHopDong'] != null && row['maHopDong'] != requestedId) {
          throw const FormatException('Chi tiết thuộc hợp đồng khác.');
        }
        final amount = row['soTien'];
        if (key != 'phanHoi' &&
            (amount is! num || !amount.isFinite || amount < 0)) {
          throw const FormatException('Số tiền chi tiết không hợp lệ.');
        }
      }
      return result;
    }

    final payments = rows('thanhToan');
    final ids = payments.map((p) => p['maThanhToan']).toList();
    if (ids.any((id) => id is! String || id.isEmpty) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Khoản thu/hoàn bị thiếu hoặc trùng mã.');
    }
    final actions =
        json['hanhDong'] is Map
            ? Map<String, dynamic>.from(json['hanhDong'] as Map)
            : <String, dynamic>{};
    for (final id in (actions['khoanHoanDuocXacNhan'] as List? ?? [])) {
      if (!payments.any(
        (p) =>
            p['maThanhToan'] == id &&
            (p['loaiThanhToan'] == 'HOAN_COC' ||
                p['loaiThanhToan'] == 'HOAN_TIEN_THUE') &&
            p['trangThai'] == 'DA_HOAN' &&
            (p['soTien'] as num) > 0,
      )) {
        throw const FormatException('Khoản hoàn chưa đủ căn cứ xác nhận.');
      }
    }
    return SettlementView(
      contractId: requestedId,
      contractStatus: json['trangThaiHopDong'] as String,
      status: json['trangThaiQuyetToan'] as String,
      hash: hash,
      receipt:
          json['nhanTra'] is Map
              ? Map<String, dynamic>.from(json['nhanTra'] as Map)
              : null,
      charges: rows('nghiaVu'),
      allocations: rows('phanBo'),
      sources: rows('nguonThu'),
      payments: payments,
      feedback: rows('phanHoi'),
      blockers: (json['lyDoChan'] as List? ?? []).whereType<String>().toList(),
      actions: actions,
      total: money('tongNghiaVu'),
      paidRental: money('thuePhiDaThu'),
      deposit: money('cocDaThu'),
      depositUsed: money('cocKhauTru'),
      collectionRemaining: money('conPhaiThu'),
      refundEntitlement: money('tongDuocHoan'),
      refundRecorded: money('daGhiHoan'),
      refundRemaining: money('conPhaiHoan'),
      gatewayReady: json['vnpaySanSang'] == true,
      stale: json['duLieuCanDoiSoat'] == true,
      reviewEligibleIds:
          (json['thietBiDuocDanhGia'] as List? ?? [])
              .whereType<String>()
              .toList(),
    );
  }

  bool get isFinal => hash != null && status == 'DA_CHOT';
  bool get isComplete => contractStatus == 'HOAN_THANH';
  bool allows(String action) => actions[action] == true && !stale;
  List<String> get receivableRefundIds =>
      (actions['khoanHoanDuocXacNhan'] as List? ?? [])
          .whereType<String>()
          .toList();
}
