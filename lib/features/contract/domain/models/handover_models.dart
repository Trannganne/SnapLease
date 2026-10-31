class BookedContractDevice {
  final String modelId;
  final String name;
  final int quantity;
  final num? pricePerDay;
  final num? rentalTotal;
  final DateTime? start;
  final DateTime? end;

  const BookedContractDevice({
    required this.modelId,
    required this.name,
    required this.quantity,
    required this.pricePerDay,
    this.rentalTotal,
    this.start,
    this.end,
  });

  factory BookedContractDevice.fromJson(Map<String, dynamic> json) =>
      BookedContractDevice(
        modelId: json['maDongMay'] as String? ?? '',
        name:
            json['tenDongMay'] as String? ?? json['maDongMay'] as String? ?? '',
        quantity: (json['soLuong'] as num?)?.toInt() ?? 0,
        pricePerDay: json['donGiaTieuChuan'] as num?,
        rentalTotal: json['thanhTien'] as num?,
        start: apiDate(json['ngayBatDau']),
        end: apiDate(json['ngayKetThuc']),
      );
}

class HandoverImage {
  final String type;
  final String url;
  final String? description;
  const HandoverImage({
    required this.type,
    required this.url,
    this.description,
  });
  factory HandoverImage.fromJson(Map<String, dynamic> json) => HandoverImage(
    type: json['loai'] as String? ?? '',
    url: json['duongDanAnh'] as String? ?? '',
    description: json['moTa'] as String?,
  );
}

class AssignedContractDevice {
  final String detailId;
  final String deviceId;
  final String modelId;
  final String? serial;
  final String? handoverCondition;
  final DateTime? handedOverAt;
  final DateTime? returnedAt;
  final List<HandoverImage> images;
  const AssignedContractDevice({
    required this.detailId,
    required this.deviceId,
    required this.modelId,
    this.serial,
    this.handoverCondition,
    this.handedOverAt,
    this.returnedAt,
    this.images = const [],
  });

  factory AssignedContractDevice.fromJson(Map<String, dynamic> json) =>
      AssignedContractDevice(
        detailId: json['maChiTietHopDong'] as String? ?? '',
        deviceId: json['maThietBi'] as String? ?? '',
        modelId: json['maDongMay'] as String? ?? '',
        serial: json['soSerial'] as String?,
        handoverCondition: json['tinhTrangLucGiao'] as String?,
        handedOverAt: apiDate(json['ngayGiaoThucTe']),
        returnedAt: apiDate(json['ngayNhanThucTe']),
        images: List.unmodifiable(
          apiRows(json['anhBienBan']).map(HandoverImage.fromJson),
        ),
      );
}

DateTime? apiDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;
List<Map<String, dynamic>> apiRows(dynamic value) =>
    value is List
        ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
        : const [];
