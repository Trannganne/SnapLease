import '../domain/models/handover_models.dart';
import '../domain/models/contract_payment_summary.dart';
import '../services/contract_pdf_service.dart';

class ContractDetailData {
  final ContractModel contract;
  final bool hasPendingDeposit;
  final bool hasSuccessfulDeposit;
  const ContractDetailData(
    this.contract,
    this.hasPendingDeposit,
    this.hasSuccessfulDeposit,
  );

  factory ContractDetailData.fromJson(
    Map<String, dynamic> json,
    String requestedId,
  ) {
    final id = json['maHopDong'] as String?;
    if (id != requestedId) {
      throw const FormatException('API trả về sai hợp đồng.');
    }
    final created = apiDate(json['ngayTaoHopDong']);
    final pickup = apiDate(json['thoiGianBanGiao']);
    final due = apiDate(json['thoiGianTraDuKien']);
    if (created == null || pickup == null || due == null) {
      throw const FormatException('API thiếu thời gian hợp đồng.');
    }
    if (json['datTheoDongMay'] is! List || json['chiTiet'] is! List) {
      throw const FormatException(
        'API thiếu danh sách đặt thuê hoặc thiết bị đã gán.',
      );
    }
    if (json['tongTien'] is! num || json['tongTienCoc'] is! num) {
      throw const FormatException('API thiếu số tiền hợp đồng.');
    }
    final bookedRows = apiRows(json['datTheoDongMay']);
    final assignedRows = apiRows(json['chiTiet']);
    if (bookedRows.length != (json['datTheoDongMay'] as List).length ||
        assignedRows.length != (json['chiTiet'] as List).length ||
        bookedRows.any(
          (row) =>
              row['maDongMay'] is! String ||
              row['soLuong'] is! num ||
              (row['soLuong'] as num) <= 0,
        ) ||
        assignedRows.any(
          (row) =>
              row['maChiTietHopDong'] is! String ||
              row['maThietBi'] is! String ||
              row['maDongMay'] is! String,
        )) {
      throw const FormatException(
        'API trả về danh sách thiết bị không hợp lệ.',
      );
    }
    final booked = List<BookedContractDevice>.unmodifiable(
      apiRows(json['datTheoDongMay']).map(BookedContractDevice.fromJson),
    );
    final assigned = List<AssignedContractDevice>.unmodifiable(
      apiRows(json['chiTiet']).map(AssignedContractDevice.fromJson),
    );
    final customer = json['khachThue'] as Map? ?? const {};
    final branch = json['chiNhanh'] as Map? ?? const {};
    final payments = apiRows(json['thanhToan']);
    final rental = json['tongTien'] as num;
    final deposit = json['tongTienCoc'] as num;
    final names =
        booked.map((row) => row.name).where((name) => name.isNotEmpty).toSet();
    final quantity = booked.fold<int>(0, (sum, row) => sum + row.quantity);
    return ContractDetailData(
      ContractModel(
        serverTimeUtc: apiDate(json['thoiGianServer'])?.toUtc(),
        receivedAtUtc: DateTime.now().toUtc(),
        canExtend: json['coTheYeuCauGiaHan'] == true,
        lateReturn:
            json['tienTraTre'] is Map
                ? Map<String, dynamic>.from(json['tienTraTre'] as Map)
                : null,
        cancellations:
            (json['yeuCauHuy'] as List? ?? [])
                .map((j) => Map<String, dynamic>.from(j as Map))
                .toList(),
        cancellationRefunds:
            (json['hoanTienHuy'] as List? ?? [])
                .map((j) => Map<String, dynamic>.from(j as Map))
                .toList(),
        contractId: id!,
        date: created,
        lessorName: 'SNAPLEASE',
        lessorAddress: branch['diaChi'] as String? ?? '',
        lessorPhone: branch['soDienThoai'] as String? ?? '',
        lesseeName: customer['hoTen'] as String? ?? '',
        lesseeId: customer['cccd'] as String? ?? '',
        lesseePhone: customer['soDienThoai'] as String? ?? '',
        deviceName: names.join(', '),
        deviceModel: names.join(', '),
        quantity: quantity,
        pricePerDay: booked.length == 1 ? booked.single.pricePerDay : null,
        pickupDate: pickup,
        returnDate: due,
        rentalDays:
            (due.difference(pickup).inSeconds / Duration.secondsPerDay).ceil(),
        branchName: branch['tenCuaHang'] as String? ?? '',
        branchId:
            json['maCuaHang'] as String? ?? branch['maCuaHang'] as String?,
        rentalTotal: rental,
        deposit: deposit,
        totalAmount: rental + deposit,
        status: json['trangThai'] as String?,
        extensions: List.unmodifiable(apiRows(json['phuLuc'])),
        bookedDevices: booked,
        assignedDevices: assigned,
        signedAt: apiDate(json['ngayKy']),
        signingMethod: json['hinhThucKy'] as String?,
        signedPdfAvailable:
            json.containsKey('maBamTepPdf')
                ? (json['maBamTepPdf'] is String &&
                    (json['maBamTepPdf'] as String).trim().isNotEmpty)
                : null,
        termsAccepted:
            json['daDongYDieuKhoan'] is bool
                ? json['daDongYDieuKhoan'] as bool
                : null,
        termsVersion: json['phienBanDieuKhoan'] as String?,
        payments: ContractPaymentSummary.fromContractJson(json),
      ),
      payments.any(
        (p) =>
            p['loaiThanhToan'] == 'TIEN_COC' &&
            p['trangThai'] == 'CHO_THANH_TOAN',
      ),
      payments.any(
        (p) =>
            p['loaiThanhToan'] == 'TIEN_COC' && p['trangThai'] == 'THANH_CONG',
      ),
    );
  }
}
