import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/formatters/rental_time_formatter.dart';
import '../../../domain/entities/device_detail.dart';

class DeviceDetailRepository {
  final Dio _dio;

  DeviceDetailRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  RentalRequestFailure _failure(DioException error, String fallback) {
    final body = error.response?.data;
    final code = body is Map ? body['code']?.toString() : null;
    final message =
        body is Map ? body['loi'] ?? body['title'] ?? body['detail'] : null;
    final status = error.response?.statusCode;
    return RentalRequestFailure(
      message?.toString() ??
          switch (code) {
            'CART_VERSION_CONFLICT' =>
              'Lựa chọn giỏ hàng đã thay đổi. Hãy kiểm tra lại giữ chỗ.',
            'HOLD_NOT_EDITABLE' =>
              'Giữ chỗ đã hết hạn hoặc không còn được chỉnh sửa.',
            _ =>
              status == 401
                  ? 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'
                  : fallback,
          },
      code: code,
      uncertain: status == null || status == 408 || status >= 500,
    );
  }

  Future<DeviceDetail> getDeviceDetail(String id) async {
    try {
      // Fetch device detail
      final detailResponse = await _dio.get('/api/dong-may/$id');
      if (detailResponse.statusCode != 200) {
        throw Exception('Failed to load device detail');
      }
      final data = detailResponse.data;

      // Fetch reviews for rating and review count
      double rating = 0.0;
      int reviewCount = 0;
      List<DeviceReview> reviewsList = [];
      try {
        final reviewResponse = await _dio.get('/api/dong-may/$id/danh-gia');
        if (reviewResponse.statusCode == 200) {
          final reviewData = reviewResponse.data;
          rating = (reviewData['diemTrungBinh'] as num?)?.toDouble() ?? 0.0;
          reviewCount = (reviewData['tongSo'] as num?)?.toInt() ?? 0;
          final List<dynamic> duLieu = reviewData['duLieu'] ?? [];
          reviewsList =
              duLieu
                  .map(
                    (json) => DeviceReview(
                      userName: json['hoTen'] as String? ?? 'Người dùng',
                      date:
                          json['ngayDanhGia'] as String? ??
                          '', // Need to format if needed
                      rating: (json['soSao'] as num?)?.toDouble() ?? 0.0,
                      comment: json['nhanXet'] as String? ?? '',
                    ),
                  )
                  .toList();
        }
      } catch (e) {
        // Fallback for review if failed
      }

      // Fetch branches for tonKho mapping
      List<BranchAvailability> branchesList = [];
      try {
        final branchResponse = await _dio.get('/api/cua-hang');
        if (branchResponse.statusCode == 200) {
          final List<dynamic> branchesData =
              (branchResponse.data is Map &&
                      branchResponse.data.containsKey('value'))
                  ? branchResponse.data['value']
                  : branchResponse.data;

          final List<dynamic> tonKhoList = data['tonKho'] ?? [];
          for (var tonKho in tonKhoList) {
            final maCuaHang = tonKho['maCuaHang'];
            final sanSang = (tonKho['sanSang'] as num?)?.toInt() ?? 0;

            final branchInfo = branchesData.firstWhere(
              (b) => b['maCuaHang'] == maCuaHang,
              orElse: () => null,
            );

            if (branchInfo != null) {
              branchesList.add(
                BranchAvailability(
                  branchId: maCuaHang,
                  branchName: branchInfo['tenCuaHang'] as String? ?? maCuaHang,
                  address: branchInfo['diaChi'] as String? ?? '',
                  availableQuantity: sanSang,
                ),
              );
            }
          }
        }
      } catch (e) {
        // Fallback for branches if failed
      }

      // Parse fields
      final giaThueNgay = (data['giaThueNgay'] as num?)?.toInt() ?? 0;
      final formattedPrice =
          '${giaThueNgay.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ/ngày';

      final tienCoc = (data['tienCoc'] as num?)?.toInt() ?? 0;
      final formattedCoc =
          '${tienCoc.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ';

      final List<dynamic> anhList = data['anh'] ?? [];
      final List<String> images =
          anhList.map((e) => e['duongDanAnh'] as String).toList();

      int totalAvailable = 0;
      for (var branch in branchesList) {
        totalAvailable += branch.availableQuantity;
      }

      return DeviceDetail(
        id: data['maDongMay'] as String,
        name: data['tenDongMay'] as String? ?? '',
        category: '${data['tenThuongHieu']} • ${data['tenDanhMuc']}',
        rating: rating,
        reviewCount: reviewCount,
        pricePerDay: formattedPrice,
        pricePerDayInt: giaThueNgay,
        availableQuantity: totalAvailable,
        images: images,
        badges: [], // Not available from API
        description: data['moTa'] as String? ?? '',
        deviceValue: 'Chưa có thông tin',
        depositRate: formattedCoc, // Mapped as fixed deposit
        estimatedDeposit: formattedCoc,
        pickupDate: '',
        pickupTime: '',
        returnDate: '',
        returnTime: '',
        rentalDays: 0,
        subtotal: '',
        discountPercent:
            data['phanTramGiamGia'] != null && data['phanTramGiamGia'] > 0
                ? 'Giảm giá ${data['phanTramGiamGia']}%'
                : '',
        discountAmount: '',
        total: '',
        branches: branchesList,
        reviews: reviewsList,
      );
    } catch (e) {
      throw Exception('Failed to load device detail: $e');
    }
  }

  String _formatDateLocal(DateTime dt) {
    return RentalTimeFormatter.wallClock(dt);
  }

  Future<int> checkAvailability(
    String maCuaHang,
    String maDongMay,
    DateTime ngayBatDau,
    DateTime ngayKetThuc,
  ) async {
    try {
      final response = await _dio.get(
        '/api/lich-trong',
        queryParameters: {
          'maCuaHang': maCuaHang,
          'maDongMay': maDongMay,
          'ngayBatDau': _formatDateLocal(ngayBatDau),
          'ngayKetThuc': _formatDateLocal(ngayKetThuc),
        },
      );
      return response.data['soLuongConTrong'] as int;
    } catch (e) {
      debugPrint('Failed to check availability: $e');
      throw Exception('Lỗi hệ thống khi kiểm tra lịch trống.');
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlyAvailability({
    required String maCuaHang,
    required String maDongMay,
    required int soLuong,
    required int thang,
    required int nam,
    String? maGiuCho,
  }) async {
    try {
      final response = await _dio.get(
        '/api/lich-trong/thang',
        queryParameters: {
          'maCuaHang': maCuaHang,
          'maDongMay': maDongMay,
          'soLuong': soLuong,
          'thang': thang,
          'nam': nam,
          if (maGiuCho != null) 'maGiuCho': maGiuCho,
        },
      );
      return List<Map<String, dynamic>>.from(response.data['ngayList']);
    } catch (e) {
      debugPrint('Failed to fetch monthly availability: $e');
      throw Exception('Không thể tải lịch. Vui lòng thử lại.');
    }
  }

  Future<Map<String, dynamic>> getPriceQuote(
    String maCuaHang,
    String maDongMay,
    int soLuong,
    DateTime ngayBatDau,
    DateTime ngayKetThuc,
  ) async {
    try {
      final response = await _dio.get(
        '/api/tam-tinh',
        queryParameters: {
          'maCuaHang': maCuaHang,
          'maDongMay': maDongMay,
          'soLuong': soLuong,
          'ngayBatDau': _formatDateLocal(ngayBatDau),
          'ngayKetThuc': _formatDateLocal(ngayKetThuc),
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint(
        'DioException in getPriceQuote: ${e.response?.statusCode} - ${e.response?.data}',
      );
      debugPrint('Request: ${e.requestOptions.uri}');
      throw Exception('Lỗi hệ thống khi tính báo giá.');
    } catch (e) {
      debugPrint('Failed to get price quote: $e');
      throw Exception('Lỗi hệ thống khi tính báo giá.');
    }
  }

  Future<Map<String, dynamic>> createReservation({
    required String maCuaHang,
    required String maDongMay,
    required int soLuong,
    required DateTime ngayBatDau,
    required DateTime ngayKetThuc,
    required String idempotencyKey,
  }) async {
    final body = {
      'maCuaHang': maCuaHang,
      'maDongMay': maDongMay,
      'soLuong': soLuong,
      'ngayBatDau': _formatDateLocal(ngayBatDau),
      'ngayKetThuc': _formatDateLocal(ngayKetThuc),
    };
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw const RentalRequestFailure('Vui lòng đăng nhập để giữ chỗ.');
    }
    final markerKey = 'direct_hold_${sha256.convert(utf8.encode(token))}';
    final payload = jsonEncode(body);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(markerKey);
    Map<String, dynamic>? previous =
        raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (previous?['id'] is String) {
      final actual = await getReservationStatus(previous!['id'] as String);
      if ([
        'HET_HAN',
        'DA_HUY',
        'DA_CHUYEN_HOP_DONG',
      ].contains(actual['trangThai'])) {
        await prefs.remove(markerKey);
        previous = null;
      } else if (previous['payload'] == payload) {
        return actual;
      }
    }
    if (previous != null && previous['payload'] != payload) {
      throw const RentalRequestFailure(
        'Lượt thuê trước chưa được đối soát. Giữ nguyên lựa chọn để kiểm tra lại hoặc hủy lượt giữ chỗ trước.',
      );
    }
    final key = previous?['key'] as String? ?? idempotencyKey;
    await prefs.setString(
      markerKey,
      jsonEncode({'key': key, 'payload': payload}),
    );
    try {
      final response = await _dio.post(
        '/api/giu-cho/thue-ngay',
        data: body,
        options: Options(headers: {'Idempotency-Key': key}),
      );
      final result = Map<String, dynamic>.from(response.data as Map);
      if (token != await TokenStorage.getToken()) {
        throw const RentalRequestFailure(
          'Phiên đăng nhập đã thay đổi.',
          uncertain: true,
        );
      }
      if (result['maGiuCho'] is String) {
        await prefs.setString(
          markerKey,
          jsonEncode({
            'key': key,
            'payload': payload,
            'id': result['maGiuCho'],
          }),
        );
      }
      return result;
    } on DioException catch (e) {
      final failure = _failure(
        e,
        'Chưa xác định kết quả giữ chỗ. Hãy kiểm tra lại; ứng dụng không tự gửi lại.',
      );
      if (!failure.uncertain) await prefs.remove(markerKey);
      throw failure;
    }
  }

  Future<Map<String, dynamic>> updateReservation({
    required String maGiuCho,
    required String maCuaHang,
    required String maDongMay,
    required int soLuong,
    required DateTime ngayBatDau,
    required DateTime ngayKetThuc,
  }) async {
    try {
      final response = await _dio.put(
        '/api/giu-cho/$maGiuCho',
        data: {
          'maCuaHang': maCuaHang,
          'maDongMay': maDongMay,
          'soLuong': soLuong,
          'ngayBatDau': _formatDateLocal(ngayBatDau),
          'ngayKetThuc': _formatDateLocal(ngayKetThuc),
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null &&
          e.response!.data is Map &&
          e.response!.data['loi'] != null) {
        final loi = e.response!.data['loi'];
        final code = e.response!.data['code'];
        if (code != null) {
          throw Exception('[$code] $loi');
        }
        throw Exception(loi);
      }
      throw Exception('Lỗi hệ thống khi cập nhật giữ chỗ.');
    }
  }

  Future<void> cancelReservation(String maGiuCho) async {
    try {
      final response = await _dio.post('/api/giu-cho/$maGiuCho/huy');
      if (response.data is! Map ||
          !['DA_HUY', 'HET_HAN'].contains(response.data['trangThai'])) {
        throw const RentalRequestFailure(
          'Chưa xác nhận hủy giữ chỗ. Hãy kiểm tra lại.',
          uncertain: true,
        );
      }
    } on DioException catch (e) {
      throw _failure(e, 'Chưa xác nhận hủy giữ chỗ. Hãy kiểm tra lại.');
    }
  }

  Future<Map<String, dynamic>> getReservationStatus(String maGiuCho) async {
    try {
      final response = await _dio.get('/api/giu-cho/$maGiuCho');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _failure(e, 'Không thể kiểm tra trạng thái giữ chỗ.');
    }
  }

  Future<Map<String, dynamic>> createContract(String maGiuCho) async {
    try {
      final response = await _dio.post('/api/giu-cho/$maGiuCho/xac-nhan-thue');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _failure(
        e,
        'Chưa xác định kết quả tạo hợp đồng. Hãy tải lại để đối soát.',
      );
    }
  }

  Future<String?> getContractIdByHold(String maGiuCho) async {
    try {
      final response = await _dio.get('/api/hop-dong/theo-giu-cho/$maGiuCho');
      return response.data['maHopDong'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception('Lỗi khi tải thông tin hợp đồng.');
    }
  }

  Future<void> cancelContract(String maHopDong) async {
    try {
      await _dio.post('/api/hop-dong/$maHopDong/huy');
    } on DioException catch (e) {
      if (e.response != null &&
          e.response!.data is Map &&
          e.response!.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi hủy hợp đồng.');
    }
  }
}

class RentalRequestFailure implements Exception {
  final String message;
  final String? code;
  final bool uncertain;
  const RentalRequestFailure(this.message, {this.code, this.uncertain = false});
  @override
  String toString() => message;
}

class ContractAlreadyCreatedException implements Exception {
  final String message;
  final String maHopDong;
  ContractAlreadyCreatedException(this.message, this.maHopDong);
  @override
  String toString() => message;
}
