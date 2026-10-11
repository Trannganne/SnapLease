class PaymentModel {
  final String maThanhToan;
  final String maHopDong;
  final int soTien;
  final String loaiThanhToan;
  final String phuongThuc;
  final String trangThai;
  final String? noiDungChuyenKhoan;
  final String? maGiaoDich;
  final DateTime? thoiGian;

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
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      maThanhToan: json['maThanhToan'] ?? '',
      maHopDong: json['maHopDong'] ?? '',
      soTien: (json['soTien'] ?? 0).toInt(),
      loaiThanhToan: json['loaiThanhToan'] ?? '',
      phuongThuc: json['phuongThuc'] ?? '',
      trangThai: json['trangThai'] ?? '',
      noiDungChuyenKhoan: json['noiDungChuyenKhoan'],
      maGiaoDich: json['maGiaoDich'],
      thoiGian: json['thoiGian'] != null ? DateTime.parse(json['thoiGian']) : null,
    );
  }
}
