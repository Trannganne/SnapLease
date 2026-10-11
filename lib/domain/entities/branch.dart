class Branch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? description;

  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.description,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['maCuaHang'] as String,
      name: json['tenCuaHang'] as String,
      address: json['diaChi'] as String?,
      phone: json['soDienThoai'] as String?,
      email: json['email'] as String?,
      description: json['moTa'] as String?,
    );
  }
}
