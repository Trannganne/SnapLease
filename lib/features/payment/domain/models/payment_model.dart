class PaymentModel {
  final String maThanhToan;
  final String maHopDong;
  final num soTien;
  final String loaiThanhToan;
  final String phuongThuc;
  final String trangThai;
  final String? noiDungChuyenKhoan;
  final String? maGiaoDich;
  final DateTime? thoiGian;
  final String? nganHang;
  final String? maBin;
  final String? soTaiKhoan;
  final String? chuTaiKhoan;
  final String? thongBao;
  final String? nhaCungCap;
  final String? maThamChieu;
  final String? duongDanThanhToan;
  final DateTime? thoiGianHetHan;
  // Outcome of the attempt just reconciled by the server; the collection's
  // canonical trangThai remains unchanged.
  final bool lastVnpayAttemptFailed;

  PaymentModel({
    required this.maThanhToan,
    required this.maHopDong,
    required this.soTien,
    required this.loaiThanhToan,
    required this.phuongThuc,
    required this.trangThai,
    this.noiDungChuyenKhoan,
    this.maGiaoDich,
    this.thoiGian,
    this.nganHang,
    this.maBin,
    this.soTaiKhoan,
    this.chuTaiKhoan,
    this.thongBao,
    this.nhaCungCap,
    this.maThamChieu,
    this.duongDanThanhToan,
    this.thoiGianHetHan,
    this.lastVnpayAttemptFailed = false,
  });

  PaymentModel withFailedVnpayAttempt() => PaymentModel(
    maThanhToan: maThanhToan,
    maHopDong: maHopDong,
    soTien: soTien,
    loaiThanhToan: loaiThanhToan,
    phuongThuc: phuongThuc,
    trangThai: trangThai,
    noiDungChuyenKhoan: noiDungChuyenKhoan,
    maGiaoDich: maGiaoDich,
    thoiGian: thoiGian,
    nganHang: nganHang,
    maBin: maBin,
    soTaiKhoan: soTaiKhoan,
    chuTaiKhoan: chuTaiKhoan,
    thongBao: thongBao,
    nhaCungCap: nhaCungCap,
    maThamChieu: maThamChieu,
    duongDanThanhToan: duongDanThanhToan,
    thoiGianHetHan: thoiGianHetHan,
    lastVnpayAttemptFailed: true,
  );

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      maThanhToan: json['maThanhToan'] ?? '',
      maHopDong: json['maHopDong'] ?? '',
      soTien: json['soTien'] as num? ?? 0,
      loaiThanhToan: json['loaiThanhToan'] ?? '',
      phuongThuc: json['phuongThuc'] ?? '',
      trangThai: json['trangThai'] ?? '',
      noiDungChuyenKhoan: json['noiDungChuyenKhoan'],
      maGiaoDich: json['maGiaoDich'],
      thoiGian:
          json['thoiGian'] != null
              ? DateTime.tryParse(json['thoiGian'].toString())
              : null,
      nganHang: json['nganHang'],
      maBin: json['maBin'],
      soTaiKhoan: json['soTaiKhoan'],
      chuTaiKhoan: json['chuTaiKhoan'],
      thongBao: json['thongBao'],
      nhaCungCap: json['nhaCungCap'],
      maThamChieu: json['maThamChieu'],
      duongDanThanhToan: json['duongDanThanhToan'] ?? json['paymentUrl'],
      thoiGianHetHan:
          json['thoiGianHetHan'] != null
              ? DateTime.tryParse(json['thoiGianHetHan'].toString())
              : null,
    );
  }
}
