import 'geo_coordinates.dart';

class Branch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? description;
  final GeoCoordinates? coordinates;

  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.description,
    this.coordinates,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['maCuaHang'] as String,
      name: json['tenCuaHang'] as String,
      address: json['diaChi'] as String?,
      phone: json['soDienThoai'] as String?,
      email: json['email'] as String?,
      description: json['moTa'] as String?,
      coordinates: GeoCoordinates.parse(json['viDo'], json['kinhDo']),
    );
  }
}
