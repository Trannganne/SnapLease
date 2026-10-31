/// Receipts from GET contract.thanhToan, not VNPAY payment attempts.
class ContractPaymentReceipt {
  final String id;
  final String type;
  final String status;
  final String method;
  final num amount;

  const ContractPaymentReceipt({
    required this.id,
    required this.type,
    required this.status,
    required this.method,
    required this.amount,
  });

  String get methodLabel => switch (method) {
    'CHUYEN_KHOAN' => 'Chuyển khoản',
    'TIEN_MAT' => 'Tiền mặt',
    'VI_DIEN_TU' => 'Ví điện tử',
    _ => method.isEmpty ? 'Chưa có thông tin phương thức' : method,
  };
}

class ContractPaymentSummary {
  final List<ContractPaymentReceipt> receipts;
  final bool complete;
  final num? depositRemaining;

  const ContractPaymentSummary({
    this.receipts = const [],
    this.complete = false,
    this.depositRemaining,
  });

  List<ContractPaymentReceipt> get successfulDeposits => receipts
      .where((p) => p.type == 'TIEN_COC' && p.status == 'THANH_CONG')
      .toList(growable: false);

  num? get depositPaid =>
      complete
          ? successfulDeposits.fold<num>(0, (sum, p) => sum + p.amount)
          : null;

  // The existing settlement API offsets rent against the deposit. It cannot
  // supply the separate rent/total balances required by this customer view.
  num? get rentalRemaining => null;
  num? get totalRemaining => null;

  factory ContractPaymentSummary.fromContractJson(Map<String, dynamic> json) {
    final raw = json['thanhToan'];
    var complete = raw is List;
    final receipts = <String, ContractPaymentReceipt>{};
    if (raw is List) {
      for (final row in raw) {
        if (row is! Map ||
            row['maThanhToan'] is! String ||
            (row['maThanhToan'] as String).trim().isEmpty ||
            row['loaiThanhToan'] is! String ||
            (row['loaiThanhToan'] as String).trim().isEmpty ||
            row['trangThai'] is! String ||
            (row['trangThai'] as String).trim().isEmpty ||
            (row['maHopDong'] != null &&
                row['maHopDong'] != json['maHopDong']) ||
            row['soTien'] is! num ||
            !(row['soTien'] as num).isFinite ||
            (row['soTien'] as num) < 0) {
          complete = false;
          continue;
        }
        final receipt = ContractPaymentReceipt(
          id: row['maThanhToan'] as String,
          type: row['loaiThanhToan'] as String,
          status: row['trangThai'] as String,
          method:
              row['phuongThuc'] is String ? row['phuongThuc'] as String : '',
          amount: row['soTien'] as num,
        );
        final prior = receipts[receipt.id];
        if (prior != null &&
            (prior.type != receipt.type ||
                prior.status != receipt.status ||
                prior.amount != receipt.amount ||
                prior.method != receipt.method)) {
          complete = false;
        }
        receipts[receipt.id] = receipt;
      }
    }
    final rows = List<ContractPaymentReceipt>.unmodifiable(receipts.values);
    final active = [
      'CHO_KY',
      'DA_KY',
      'CHO_BAN_GIAO',
      'DANG_THUE',
    ].contains(json['trangThai']);
    final refunds = rows.any(
      (p) => p.type == 'HOAN_COC' && p.status != 'THAT_BAI',
    );
    // Supplementary deposit obligations must be confirmed separately.
    final supplements = json['phuLuc'];
    final noExtraDeposit =
        supplements is List &&
        supplements.every(
          (row) =>
              row is Map &&
              row['tienCocBoSung'] is num &&
              row['tienCocBoSung'] == 0,
        );
    final required = json['tongTienCoc'];
    final paid = rows
        .where((p) => p.type == 'TIEN_COC' && p.status == 'THANH_CONG')
        .fold<num>(0, (sum, p) => sum + p.amount);
    return ContractPaymentSummary(
      receipts: rows,
      complete: complete,
      depositRemaining:
          complete &&
                  active &&
                  !refunds &&
                  noExtraDeposit &&
                  required is num &&
                  required.isFinite &&
                  required >= paid
              ? required - paid
              : null,
    );
  }
}
