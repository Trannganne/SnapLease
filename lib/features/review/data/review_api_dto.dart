import '../domain/models/review_detail_model.dart';
import '../domain/models/review_form.dart';
import '../domain/models/review_highlight_chip.dart';
import '../domain/models/review_target_device.dart';

// API DTOs deliberately do not use the English preview JSON parsers.
class ReviewApiDto {
  static Map<String, dynamic> object(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Dữ liệu Đánh giá không hợp lệ.');
    }
    return value;
  }

  static String requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('API thiếu $key.');
    }
    return value;
  }

  static List<Map<String, dynamic>> rows(dynamic value) {
    if (value is! List) throw const FormatException('API thiếu danh sách.');
    return value.map(object).toList();
  }

  static ReviewForm form(dynamic value, String detailId) {
    final j = object(value);
    if (requiredString(j, 'maChiTietHopDong') != detailId ||
        j['duocDanhGia'] is! bool ||
        j['gioiHanNhanXet'] is! int ||
        (j['gioiHanNhanXet'] as int) <= 0 ||
        j['gioiHanAnh'] is! int ||
        (j['gioiHanAnh'] as int) < 0) {
      throw const FormatException('Biểu mẫu Đánh giá không hợp lệ.');
    }
    return ReviewForm(
      device: ReviewTargetDevice(
        contractId: requiredString(j, 'maHopDong'),
        detailId: detailId,
        deviceId: requiredString(j, 'maThietBi'),
        modelId: requiredString(j, 'maDongMay'),
        modelName: requiredString(j, 'tenDongMay'),
        brandName: j['tenThuongHieu'] as String?,
        categoryName: j['tenDanhMuc'] as String?,
        branchName: '',
        serialNumber: j['soSerial'] as String?,
        deviceImageUrl: j['anhDaiDien'] as String?,
        contractStatus: requiredString(j, 'trangThaiHopDong'),
      ),
      canReview: j['duocDanhGia'] as bool,
      reason: j['lyDoKhongTheDanhGia'] as String?,
      existingReviewId: j['maDanhGiaDaCo'] as String?,
      commentLimit: j['gioiHanNhanXet'] as int,
      imageLimit: j['gioiHanAnh'] as int,
      highlights:
          rows(j['diemNoiBatMacDinh'])
              .where((x) => x['ma'] != 'PHU_KIEN_DAY_DU')
              .map(
                (x) => ReviewHighlightChip(
                  id: requiredString(x, 'ma'),
                  label: requiredString(x, 'ten'),
                ),
              )
              .toList(),
    );
  }

  static ReviewDetailModel review(dynamic value) {
    final j = object(value);
    final stars = j['soSao'];
    final date = DateTime.tryParse(requiredString(j, 'ngayDanhGia'));
    if (stars is! int || stars < 1 || stars > 5 || date == null) {
      throw const FormatException('Đánh giá thiếu số sao hoặc ngày gửi.');
    }
    final status =
        j['trangThaiHienThi'] as String? ?? j['trangThaiKiemDuyet'] as String?;
    final images = rows(j['hinhAnh']);
    return ReviewDetailModel(
      reviewId: requiredString(j, 'maDanhGia'),
      detailId: requiredString(j, 'maChiTietHopDong'),
      rating: stars,
      comment: j['nhanXet'] as String? ?? '',
      highlights:
          rows(j['diemNoiBat'])
              .where((x) => x['ma'] != 'PHU_KIEN_DAY_DU')
              .map((x) => requiredString(x, 'ten'))
              .toList(),
      imageUrls: images.map((x) => requiredString(x, 'duongDanAnh')).toList(),
      imageIds: images.map((x) => requiredString(x, 'maAnhDanhGia')).toList(),
      reviewerName: j['hoTenKhachHang'] as String? ?? '',
      reviewedAt: date,
      moderationStatus: status ?? 'UNKNOWN',
      moderationNote: j['ghiChuKiemDuyet'] as String?,
      isApproved: false, // Publication does not imply staff approval.
      isPublic: status == 'CONG_KHAI' || status == 'DA_DUYET',
      // chinhHang is hard-coded by this backend and is not evidence of certification.
      isVerifiedRenter: false,
    );
  }
}
