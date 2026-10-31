import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/appendix_pdf_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../domain/models/extension_models.dart';
import '../../domain/models/settlement_view.dart';

class ContractRepository {
  final Dio _dio;

  ContractRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  // Only a recovery key is local; financial state always comes from Backend.
  Future<Map<String, dynamic>?> pendingSettlementOperation(String id) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'settlement_operation_$id',
    );
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> rememberSettlementOperation(
    String id,
    Map<String, dynamic>? marker,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (marker == null) {
      await prefs.remove('settlement_operation_$id');
    } else {
      await prefs.setString('settlement_operation_$id', jsonEncode(marker));
    }
  }

  Future<Map<String, dynamic>> reconcileSettlementOperation(
    String id,
    String operation,
    String kind,
  ) async {
    final response = await _dio.get(
      '/api/hop-dong/$id/quyet-toan/thao-tac/$operation',
      queryParameters: {'loai': kind},
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    if (json['maHopDong'] != id || json['daGhiNhan'] is! bool) {
      throw const FormatException('Chưa đối soát được thao tác.');
    }
    return json;
  }

  Future<SettlementView> getSettlement(String contractId) async {
    try {
      final response = await _dio.get('/api/hop-dong/$contractId/quyet-toan');
      return SettlementView.fromJson(
        Map<String, dynamic>.from(response.data as Map),
        contractId,
      );
    } on DioException catch (error) {
      throw _settlementFailure(error);
    }
  }

  Future<void> sendSettlementFeedback(
    String contractId, {
    required String hash,
    required String operationId,
    required String type,
    String? paymentId,
    String? reason,
    String? feedbackId,
    num? expectedAmount,
    String? replySeenAt,
  }) async {
    try {
      await _dio.post(
        '/api/hop-dong/$contractId/quyet-toan/phan-hoi',
        data: {
          'operationId': operationId,
          'maBamQuyetToan': hash,
          'loai': type,
          'maThanhToan': paymentId,
          'lyDo': reason,
          'phanHoiId': feedbackId,
          'soTienXacNhan': expectedAmount,
          'traLoiLucUtcDaXem': replySeenAt,
        },
      );
    } on DioException catch (error) {
      throw _settlementFailure(error, writing: true);
    }
  }

  Future<String> createSettlementCollection(
    String contractId, {
    required String hash,
    required String operationId,
  }) async {
    try {
      final response = await _dio.post(
        '/api/hop-dong/$contractId/quyet-toan/thu-them',
        data: {
          'operationId': operationId,
          'maBamQuyetToan': hash,
          'phuongThuc': 'VI_DIEN_TU',
        },
      );
      final json = Map<String, dynamic>.from(response.data as Map);
      if (json['maThanhToan'] is! String || json['maHopDong'] != contractId) {
        throw const SettlementFailure(
          'Chưa xác định khoản thu. Hãy tải lại để đối soát.',
          uncertain: true,
        );
      }
      return json['maThanhToan'] as String;
    } on DioException catch (error) {
      throw _settlementFailure(error, writing: true);
    }
  }

  SettlementFailure _settlementFailure(
    DioException error, {
    bool writing = false,
  }) {
    final status = error.response?.statusCode;
    final uncertain =
        writing && (status == null || status == 408 || status >= 500);
    final body = error.response?.data;
    final message =
        body is Map ? body['loi'] ?? body['title'] ?? body['detail'] : null;
    return SettlementFailure(
      uncertain
          ? 'Chưa rõ kết quả. Không gửi lại; hãy tải lại để đối soát.'
          : message?.toString() ?? 'Không thể tải hoặc xử lý quyết toán.',
      uncertain: uncertain,
    );
  }

  Future<Map<String, dynamic>> getAppendix(String id) async =>
      Map<String, dynamic>.from(
        (await _dio.get('/api/gia-han/$id')).data as Map,
      );
  Future<Uint8List> loadAppendixPdf(String id) async {
    var row = await getAppendix(id);
    if (row['maBamTepPdf'] == null) {
      if (row['trangThai'] != 'CHO_KY') {
        throw StateError('Phụ lục không còn chờ ký.');
      }
      final bytes = await AppendixPdfService().generate(row);
      try {
        await _dio.put(
          '/api/gia-han/$id/tep-pdf',
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Length': bytes.length,
            },
          ),
        );
      } on DioException {
        row = await getAppendix(id);
        if (row['maBamTepPdf'] == null) rethrow;
      }
    }
    final response = await _dio.get<List<int>>(
      '/api/gia-han/$id/tep-pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<Map<String, dynamic>> getCancellation(String id) async =>
      Map<String, dynamic>.from(
        (await _dio.get('/api/hop-dong/$id/huy-truoc-ban-giao')).data as Map,
      );
  Future<void> requestCancellation(String id, String reason) async {
    try {
      await _dio.post(
        '/api/hop-dong/$id/huy-truoc-ban-giao',
        data: {'lyDo': reason},
      );
    } on DioException catch (e) {
      throw StateError(
        e.response?.data is Map
            ? (e.response!.data['loi'] ?? 'Không thể yêu cầu hủy.').toString()
            : 'Chưa xác định kết quả yêu cầu hủy. Hãy tải lại để đối soát.',
      );
    }
  }

  Future<ExtensionQuote> previewExtension(String id, DateTime date) async {
    try {
      final response = await _dio.get(
        '/api/hop-dong/$id/du-kien-gia-han',
        queryParameters: {'thoiHanTraMoi': date.toIso8601String()},
      );
      return ExtensionQuote.fromJson(Map<String, dynamic>.from(response.data));
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['coTheGiaHan'] is bool) {
        return ExtensionQuote.fromJson(Map<String, dynamic>.from(data));
      }
      throw _extensionFailure(error);
    }
  }

  Future<Map<String, dynamic>> requestExtension(
    String id,
    DateTime date,
    String reason,
  ) async {
    try {
      final response = await _dio.post(
        '/api/hop-dong/$id/yeu-cau-gia-han',
        data: {
          'thoiHanTraMoi': date.toIso8601String(),
          'lyDoGiaHan': reason.trim(),
          'ghiChu': null,
        },
      );
      final data = Map<String, dynamic>.from(response.data);
      if (response.statusCode != 201 ||
          data['maHopDong'] != id ||
          data['maPhuLuc'] is! String ||
          data['trangThai'] != 'CHO_XAC_NHAN') {
        throw const ExtensionFailure(
          'Chưa xác định kết quả gửi yêu cầu. Hãy tải lại hợp đồng.',
          uncertain: true,
        );
      }
      return data;
    } on DioException catch (error) {
      throw _extensionFailure(error, posting: true);
    }
  }

  ExtensionFailure _extensionFailure(
    DioException error, {
    bool posting = false,
  }) {
    final data = error.response?.data;
    final status = error.response?.statusCode;
    final uncertain =
        posting && (status == null || status == 408 || status >= 500);
    final message =
        data is Map ? data['loi'] ?? data['lyDo'] ?? data['title'] : null;
    return ExtensionFailure(
      uncertain
          ? 'Chưa xác định kết quả gửi yêu cầu. Không tự gửi lại; hãy tải lại để đối soát phụ lục.'
          : message?.toString() ??
              switch (status) {
                401 => 'Phiên đăng nhập đã hết hạn.',
                403 => 'Bạn không có quyền gia hạn hợp đồng này.',
                404 => 'Không tìm thấy hợp đồng thuộc tài khoản của bạn.',
                _ => 'Không thể xử lý gia hạn. Vui lòng thử lại.',
              },
      uncertain: uncertain,
    );
  }

  Future<List<int>> getHandoverImage(String url) async {
    final base = Uri.parse(ApiConfig.baseUrl);
    final uri = base.resolve(url);
    if (!['http', 'https'].contains(uri.scheme) || uri.userInfo.isNotEmpty) {
      throw const FormatException('Đường dẫn ảnh không hợp lệ.');
    }
    // Only the configured API origin receives the authenticated interceptor.
    final sameOrigin = uri.origin == base.origin;
    final client =
        sameOrigin
            ? _dio
            : Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );
    try {
      final response = await client.get<List<int>>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Ảnh rỗng.');
      }
      return bytes;
    } finally {
      if (!sameOrigin) client.close();
    }
  }

  Future<Map<String, dynamic>> getContractById(String contractId) async {
    try {
      final response = await _dio.get('/api/hop-dong/$contractId');
      final data = Map<String, dynamic>.from(response.data as Map);
      final requests = data['yeuCauHuy'];
      if (data['maHopDong'] == contractId &&
          data['trangThai'] == 'DA_HUY' &&
          requests is List &&
          requests.whereType<Map>().any(
            (r) => r['trangThai'] == 'DA_DUYET' && r['xuLyLucUtc'] == null,
          )) {
        // The detail projection omits processing metadata. Reuse the existing
        // owner-authorized GET; its failure must not hide a canceled contract.
        try {
          final history = (await getCancellation(contractId))['yeuCau'];
          if (history is List) {
            data['yeuCauHuy'] =
                requests.map((row) {
                  if (row is! Map || row['trangThai'] != 'DA_DUYET') return row;
                  final matches = history.whereType<Map>().where(
                    (h) =>
                        h['maHopDong'] == contractId &&
                        row['id'] is String &&
                        (row['id'] as String).isNotEmpty &&
                        h['id'] == row['id'] &&
                        h['trangThai'] == 'DA_DUYET',
                  );
                  if (matches.length != 1) return row;
                  final match = matches.single;
                  return {
                    ...row,
                    if (match['xuLyLucUtc'] is String)
                      'xuLyLucUtc': match['xuLyLucUtc'],
                    if (match['lyDoXuLy'] is String)
                      'lyDoXuLy': match['lyDoXuLy'],
                  };
                }).toList();
          }
        } on DioException {
          // Known detail fields remain usable when optional history is offline.
        } on TypeError {
          // A malformed optional response cannot invent cancellation history.
        }
      }
      return data;
    } on DioException catch (e) {
      if (e.response != null &&
          e.response!.data is Map &&
          e.response!.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi tải hợp đồng.');
    }
  }

  Future<void> cancelContract(String contractId) async {
    try {
      await _dio.post('/api/hop-dong/$contractId/huy');
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

class SettlementFailure implements Exception {
  final String message;
  final bool uncertain;
  const SettlementFailure(this.message, {this.uncertain = false});
  @override
  String toString() => message;
}
