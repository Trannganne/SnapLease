class CustomerProfile {
  final String hoTen;
  final String soDienThoai;
  final String? email;
  final String? cccd;
  final String? diaChiThuongTru;
  final String? ngaySinh;
  final String? gioiTinh;
  final String? quocTich;
  final String? ngayCap;
  final String? noiCap;
  final bool daXacNhanThongTin;

  const CustomerProfile({
    required this.hoTen,
    required this.soDienThoai,
    this.email,
    this.cccd,
    this.diaChiThuongTru,
    this.ngaySinh,
    this.gioiTinh,
    this.quocTich,
    this.ngayCap,
    this.noiCap,
    required this.daXacNhanThongTin,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      hoTen: json['hoTen'] ?? '',
      soDienThoai: json['soDienThoai'] ?? '',
      email: json['email'],
      cccd: json['cccd'],
      diaChiThuongTru: json['diaChiThuongTru'],
      ngaySinh: json['ngaySinh'],
      gioiTinh: json['gioiTinh'],
      quocTich: json['quocTich'],
      ngayCap: json['ngayCap'],
      noiCap: json['noiCap'],
      daXacNhanThongTin: json['daXacNhanThongTin'] ?? false,
    );
  }
}
