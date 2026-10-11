import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import '../services/identity_scanner.dart';
import '../../../domain/entities/customer_profile.dart';

class IdentityVerificationRepository {
  final Dio _dio = ApiClient.instance;

  Future<String> uploadIdentityDocuments({
    required XFile frontImage,
    required XFile backImage,
    required String cccd,
    required String hoTen,
  }) async {
    // Read files as bytes
    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();

    final frontBase64 = 'data:image/jpeg;base64,${base64Encode(frontBytes)}';
    final backBase64 = 'data:image/jpeg;base64,${base64Encode(backBytes)}';

    try {
      final response = await _dio.post(
        '/api/giay-to',
        data: {
          'HoTen': hoTen,
          'LoaiGiayTo': 'CCCD',
          'SoGiayTo': cccd,
          'MatTruocUrl': frontBase64,
          'MatSauUrl': backBase64,
        },
      );

      if (response.statusCode == 201) {
        return response.data['maGiayTo'];
      } else {
        throw Exception('Lỗi khi tải ảnh giấy tờ.');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi tải ảnh giấy tờ: ${e.message}');
    }
  }

  Future<void> confirmIdentity({
    required String maGiayTo,
    required ExtractedIdentityData data,
  }) async {
    try {
      final response = await _dio.post(
        '/api/khach-thue/xac-nhan-danh-tinh',
        data: {
          'MaGiayTo': maGiayTo,
          'Cccd': data.cccd?.value,
          'HoTen': data.hoTen?.value,
          'NgaySinh': data.ngaySinh?.value,
          'GioiTinh': data.gioiTinh?.value,
          'QuocTich': data.quocTich?.value,
          'DiaChiThuongTru': data.diaChiThuongTru?.value,
          'NgayCap': data.ngayCap?.value,
          'NoiCap': data.noiCap?.value,
        },
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['loi'] ?? 'Lỗi khi xác nhận danh tính.');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi xác nhận danh tính: ${e.message}');
    }
  }

  Future<CustomerProfile> getCustomerProfile() async {
    try {
      final response = await _dio.get('/api/khach-thue/cua-toi');
      if (response.statusCode == 200) {
        return CustomerProfile.fromJson(response.data);
      } else {
        throw Exception('Không thể lấy thông tin khách thuê.');
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống: ${e.message}');
    }
  }
}
