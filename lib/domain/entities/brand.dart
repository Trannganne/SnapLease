class Brand {
  final String id;
  final String name;
  final String? country;

  const Brand({
    required this.id,
    required this.name,
    this.country,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['maThuongHieu'] as String,
      name: json['tenThuongHieu'] as String,
      country: json['quocGia'] as String?,
    );
  }
}
