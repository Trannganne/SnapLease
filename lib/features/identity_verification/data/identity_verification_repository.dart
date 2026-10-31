import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import '../services/identity_scanner.dart';
import '../../../domain/entities/customer_profile.dart';

class IdentityVerificationRepository {
  final Dio _dio;
  IdentityVerificationRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  // Only show known business messages; never display arbitrary error bodies or exceptions.
  String? _businessMessage(DioException error) {
    final body = error.response?.data;
    if (body is! Map) return null;
    final message = body['loi'];
    const allowed = {
      'Thông tin giấy tờ không hợp lệ.',
      'Số giấy tờ đã được sử dụng bởi khách thuê khác.',
      'Giấy tờ đã được gửi. Vui lòng kiểm tra hồ sơ hiện có trước khi gửi lại.',
      'Thiếu thông tin xác nhận danh tính (cần đủ 8 trường bắt buộc).',
      'Không tìm thấy giấy tờ.',
      'Giấy tờ chưa đủ 2 mặt ảnh thực tế.',
      'CCCD xác nhận không khớp giấy tờ đã tải lên.',
      'Thông tin danh tính không hợp lệ.',
      'CCCD đã được sử dụng bởi khách thuê khác.',
    };
    if (allowed.contains(message)) return message as String;
    for (final side in ['Mặt trước', 'Mặt sau']) {
      for (final reason in [
        'Ảnh phải được tải lên hoặc thuộc giấy tờ của bạn.',
        'Chuỗi ảnh Base64 không hợp lệ.',
        'Chuỗi Base64 không hợp lệ.',
        'Ảnh vượt quá dung lượng cho phép (10MB).',
        'Tệp không phải là hình ảnh hợp lệ hoặc bị hỏng.',
      ]) {
        if (message == '$side: $reason') return message as String;
      }
    }
    return null;
  }

  Options? _sessionOptions(String? token) =>
      token == null
          ? null
          : Options(
            headers: {'Authorization': 'Bearer $token'},
            extra: {ApiClient.boundSession: true},
          );

  Future<String> uploadIdentityDocuments({
    required XFile frontImage,
    required XFile backImage,
    required String cccd,
    required String hoTen,
    String? sessionToken,
  }) async {
    final generation = TokenStorage.generation;
    final token = sessionToken ?? await TokenStorage.getToken();
    if (await frontImage.length() > 10 * 1024 * 1024 ||
        await backImage.length() > 10 * 1024 * 1024) {
      throw const IdentityRequestFailure(
        'Ảnh CCCD vượt quá 10MB. Vui lòng chụp lại.',
      );
    }
    final frontBytes = await frontImage.readAsBytes();
    final backBytes = await backImage.readAsBytes();

    if (TokenStorage.isChanging ||
        generation != TokenStorage.generation ||
        token == null) {
      throw const IdentityRequestFailure(
        'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.',
      );
    }

    final frontBase64 = 'data:image/jpeg;base64,${base64Encode(frontBytes)}';
    final backBase64 = 'data:image/jpeg;base64,${base64Encode(backBytes)}';

    try {
      final response = await _dio.post(
        '/api/giay-to',
        options: _sessionOptions(token),
        data: {
          'HoTen': hoTen,
          'LoaiGiayTo': 'CCCD',
          'SoGiayTo': cccd,
          'MatTruocUrl': frontBase64,
          'MatSauUrl': backBase64,
        },
      );

      if (response.statusCode == 201 &&
          response.data is Map &&
          response.data['maGiayTo'] is String &&
          (response.data['maGiayTo'] as String).isNotEmpty) {
        return response.data['maGiayTo'];
      } else {
        throw const IdentityRequestFailure(
          'Chưa xác định được kết quả tải giấy tờ. Hãy kiểm tra hồ sơ trước khi gửi lại.',
          uncertain: true,
        );
      }
    } on DioException catch (e) {
      final uncertain =
          e.response == null || (e.response?.statusCode ?? 0) >= 500;
      if (uncertain) {
        // Read back only. A matching number alone cannot prove these photos were saved.
        bool found = false;
        try {
          final saved = await getSavedIdentity(sessionToken: token);
          found = saved.documentNumber == cccd.trim();
        } catch (_) {
          /* Preserve the unknown POST result if readback also fails. */
        }
        if (found) {
          throw const IdentityRequestFailure(
            'Máy chủ đã có giấy tờ cùng số. Hãy mở lại hồ sơ để kiểm tra trước khi gửi lại.',
            uncertain: true,
          );
        }
      }
      throw IdentityRequestFailure(
        uncertain
            ? 'Chưa xác định được kết quả tải giấy tờ. Hãy kiểm tra hồ sơ trước khi gửi lại.'
            : _businessMessage(e) ??
                (e.response?.statusCode == 401
                    ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
                    : e.response?.statusCode == 403
                    ? 'Bạn không có quyền tải giấy tờ cho hồ sơ này.'
                    : 'Không thể tải giấy tờ (HTTP ${e.response?.statusCode}). Vui lòng thử lại.'),
        uncertain: uncertain,
      );
    }
  }

  Future<void> confirmIdentity({
    required String maGiayTo,
    required ExtractedIdentityData data,
    String? sessionToken,
  }) async {
    try {
      final response = await _dio.post(
        '/api/khach-thue/xac-nhan-danh-tinh',
        options: _sessionOptions(sessionToken),
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
        throw const IdentityRequestFailure(
          'Không thể xác nhận thông tin danh tính.',
        );
      }
    } on DioException catch (e) {
      final uncertain =
          e.response == null || (e.response?.statusCode ?? 0) >= 500;
      if (uncertain) {
        try {
          final saved = await getSavedIdentity(sessionToken: sessionToken);
          final p = saved.profile;
          if (saved.documentId == maGiayTo &&
              saved.matchesProfile &&
              p.hoTen == data.hoTen?.value.trim() &&
              p.ngaySinh == data.ngaySinh?.value &&
              p.gioiTinh == data.gioiTinh?.value.trim() &&
              p.quocTich == data.quocTich?.value.trim() &&
              p.diaChiThuongTru == data.diaChiThuongTru?.value.trim() &&
              p.ngayCap == data.ngayCap?.value &&
              p.noiCap == data.noiCap?.value.trim()) {
            return;
          }
        } catch (_) {
          /* Never repeat an uncertain confirmation POST automatically. */
        }
      }
      throw IdentityRequestFailure(
        _businessMessage(e) ??
            'Chưa xác nhận được thông tin. Vui lòng kiểm tra lại hồ sơ trước khi thử lại.',
        uncertain: uncertain,
      );
    }
  }

  Future<CustomerProfile> getCustomerProfile({String? sessionToken}) async {
    try {
      final response = await _dio.get(
        '/api/khach-thue/cua-toi',
        options: _sessionOptions(sessionToken),
      );
      if (response.statusCode == 200) {
        return CustomerProfile.fromJson(response.data);
      } else {
        throw Exception('Không thể lấy thông tin khách thuê.');
      }
    } on DioException {
      throw const IdentityRequestFailure(
        'Không thể tải hồ sơ. Vui lòng thử lại.',
      );
    }
  }

  Future<String?> getLatestDocumentStatus({
    required String sessionToken,
  }) async {
    final response = await _dio.get(
      '/api/giay-to/cua-toi',
      options: _sessionOptions(sessionToken),
    );
    final documents = response.data as List;
    // API orders newest first, matching the contract's identity guard.
    if (documents.isEmpty) return null;
    final latest = documents.first as Map;
    return latest['trangThaiXacMinh'] as String?;
  }

  Future<
    ({
      CustomerProfile profile,
      String? documentId,
      String? documentNumber,
      String? status,
      bool hasImages,
      bool matchesProfile,
    })
  >
  getSavedIdentity({String? sessionToken}) async {
    final token = sessionToken ?? await TokenStorage.getToken();
    if (token == null) {
      throw const IdentityRequestFailure('Vui lòng đăng nhập lại.');
    }
    final profile = await getCustomerProfile(sessionToken: token);
    final response = await _dio.get(
      '/api/giay-to/cua-toi',
      options: _sessionOptions(token),
    );
    final documents = response.data as List;
    final latest = documents.isEmpty ? null : documents.first as Map;
    bool nonBlank(Object? value) => value is String && value.trim().isNotEmpty;
    final hasImages =
        nonBlank(latest?['matTruocUrl']) && nonBlank(latest?['matSauUrl']);
    return (
      profile: profile,
      documentId: latest?['maGiayTo'] as String?,
      documentNumber: latest?['soGiayTo'] as String?,
      status: latest?['trangThaiXacMinh'] as String?,
      hasImages: hasImages,
      matchesProfile:
          profile.daXacNhanThongTin &&
          nonBlank(profile.cccd) &&
          latest?['loaiGiayTo'] == 'CCCD' &&
          latest?['soGiayTo'] == profile.cccd &&
          hasImages,
    );
  }
}

class IdentityRequestFailure implements Exception {
  final String message;
  final bool uncertain;
  const IdentityRequestFailure(this.message, {this.uncertain = false});
  @override
  String toString() => message;
}
