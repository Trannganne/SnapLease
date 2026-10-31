import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/repositories/contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';

/// Adapts the existing signing Cubit and OTP dialog to a separate appendix.
class AppendixSigningRepository implements ContractSigningRepository {
  final String appendixId;
  final Dio dio;
  String? _contentHash;
  AppendixSigningRepository(this.appendixId, {Dio? dio})
    : dio = dio ?? ApiClient.instance;
  Future<T> _session<T>(Future<T> Function() call) async {
    final token = await TokenStorage.getToken();
    if (token == null) throw StateError('Vui lòng đăng nhập.');
    try {
      final result = await call();
      if (token != await TokenStorage.getToken()) {
        throw StateError('Phiên đăng nhập đã thay đổi.');
      }
      return result;
    } on DioException catch (e) {
      throw StateError(
        e.response?.data is Map
            ? (e.response!.data['loi'] ?? 'Không thể xử lý phụ lục.').toString()
            : 'Chưa xác định kết quả. Tải lại phụ lục để đối soát trước khi thử lại.',
      );
    }
  }

  @override
  Future<OtpRequestResult> uploadPdfAndRequestOtp(
    ContractModel contract,
    Uint8List bytes,
    bool accepted,
  ) => _session(() async {
    if (!accepted) throw StateError('Cần đồng ý nội dung phụ lục.');
    var row = Map<String, dynamic>.from(
      (await dio.get('/api/gia-han/$appendixId')).data as Map,
    );
    if (row['trangThai'] != 'CHO_KY') {
      throw StateError('Phụ lục không còn chờ ký.');
    }
    if (row['maBamTepPdf'] == null) {
      try {
        await dio.put(
          '/api/gia-han/$appendixId/tep-pdf',
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': 'application/pdf',
              'Content-Length': bytes.length,
            },
          ),
        );
      } on DioException {
        row = Map<String, dynamic>.from(
          (await dio.get('/api/gia-han/$appendixId')).data as Map,
        );
        if (row['maBamTepPdf'] == null) rethrow;
      }
    }
    final data = Map<String, dynamic>.from(
      (await dio.post('/api/gia-han/$appendixId/yeu-cau-ky')).data as Map,
    );
    _contentHash = data['maBamNoiDung'] as String;
    return OtpRequestResult(
      maXacNhan: data['maXacNhan'] as String,
      emailMask: 'email đã đăng ký',
      expiredAt: DateTime.parse(data['hetHanLuc'] as String),
    );
  });
  @override
  Future<ContractModel> verifyOtp(
    ContractModel contract,
    String confirmation,
    String otp,
    bool accepted,
  ) => _session(() async {
    Map<String, dynamic> row;
    try {
      row = Map<String, dynamic>.from(
        (await dio.put(
              '/api/gia-han/$appendixId/ky',
              data: {
                'maXacNhan': confirmation,
                'maOtp': otp,
                'maBamNoiDung': _contentHash,
                'daDongYDieuKhoan': accepted,
              },
            )).data
            as Map,
      );
    } on DioException catch (e) {
      if (e.response != null && (e.response!.statusCode ?? 500) < 500) rethrow;
      row = Map<String, dynamic>.from(
        (await dio.get('/api/gia-han/$appendixId')).data as Map,
      );
      if (row['trangThai'] != 'DA_HIEU_LUC') rethrow;
    }
    if (row['trangThai'] != 'DA_HIEU_LUC') {
      throw StateError('Phụ lục chưa có hiệu lực.');
    }
    return contract.copyWith(
      extensions: [
        ...contract.extensions.where((p) => p['maPhuLuc'] != appendixId),
        row,
      ],
    );
  });
}
