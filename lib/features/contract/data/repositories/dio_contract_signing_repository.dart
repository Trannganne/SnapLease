import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/formatters/rental_time_formatter.dart';
import '../../domain/repositories/contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';

String _otpFailureMessage(DioException error, String action) {
  final body = error.response?.data;
  if (body is Map) {
    for (final key in const ['loi', 'title', 'detail']) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
  }
  final status = error.response?.statusCode;
  if (status != null) {
    if (status >= 500) {
      return 'Máy chủ gặp lỗi khi $action (HTTP $status). Vui lòng liên hệ hỗ trợ.';
    }
    return 'Yêu cầu không được chấp nhận khi $action (HTTP $status).';
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      // A timeout does not prove that the signing request was not processed.
      return 'Hết thời gian chờ khi $action. Chưa xác định kết quả; vui lòng tải lại trạng thái trước khi thử lại.';
    case DioExceptionType.connectionError:
      return 'Không thể kết nối máy chủ khi $action. Vui lòng kiểm tra kết nối.';
    default:
      return 'Không thể hoàn tất $action. Vui lòng tải lại trạng thái.';
  }
}

class DioContractSigningRepository implements ContractSigningRepository {
  final Dio _dio;
  DioContractSigningRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  @override
  Future<OtpRequestResult> uploadPdfAndRequestOtp(
    ContractModel contract,
    Uint8List pdfBytes,
    bool daDongYDieuKhoan,
  ) async {
    try {
      await _dio.put(
        '/api/hop-dong/${contract.contractId}/tep-pdf',
        data: Stream.fromIterable([pdfBytes]),
        options: Options(
          headers: {
            'Content-Type': 'application/pdf',
            'Content-Length': pdfBytes.length.toString(),
          },
        ),
      );

      final otpResponse = await _dio.post(
        '/api/hop-dong/${contract.contractId}/yeu-cau-ky',
        data: {'daDongYDieuKhoan': daDongYDieuKhoan},
      );

      final data = otpResponse.data;
      return OtpRequestResult(
        maXacNhan: data['maXacNhan'],
        emailMask: data['emailNhan'] ?? data['emailMask'] ?? '',
        expiredAt: RentalTimeFormatter.instant(
          data['hetHanLuc'] as String,
          vietnamLocal: true,
        ),
      );
    } on DioException catch (e) {
      final action =
          e.requestOptions.path.endsWith('/tep-pdf')
              ? 'tải PDF hợp đồng'
              : 'yêu cầu OTP';
      throw _otpFailureMessage(e, action);
    } catch (e) {
      throw 'Lỗi không xác định: $e';
    }
  }

  @override
  Future<ContractModel> verifyOtp(
    ContractModel contract,
    String maXacNhan,
    String otp,
    bool daDongYDieuKhoan,
  ) async {
    bool signed(Map data) =>
        (data['maHopDong'] == null ||
            data['maHopDong'] == contract.contractId) &&
        const [
          'DA_KY',
          'CHO_BAN_GIAO',
          'DANG_THUE',
          'CHO_HOAN_TRA',
          'HOAN_THANH',
        ].contains(data['trangThai']);
    Future<ContractModel> readConfirmed() async {
      final response = await _dio.get('/api/hop-dong/${contract.contractId}');
      final data = response.data;
      if (data is! Map ||
          data['maHopDong'] != contract.contractId ||
          !signed(data)) {
        throw StateError(
          'Backend chưa xác nhận hợp đồng đã ký. Hãy tải lại trạng thái.',
        );
      }
      return contract.copyWith(status: data['trangThai'] as String);
    }

    try {
      final response = await _dio.put(
        '/api/hop-dong/${contract.contractId}/ky',
        data: {
          'maXacNhan': maXacNhan,
          'maOtp': otp,
          'daDongYDieuKhoan': daDongYDieuKhoan,
        },
      );

      final data = response.data;
      if (data is Map && signed(data)) {
        return contract.copyWith(status: data['trangThai']);
      }
      return await readConfirmed();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == null || status == 408 || status >= 500) {
        try {
          return await readConfirmed();
        } catch (_) {
          // Never repeat PUT /ky or infer signing success from an OTP timeout.
        }
      }
      throw _otpFailureMessage(e, 'xác nhận OTP');
    } catch (e) {
      throw 'Lỗi không xác định: $e';
    }
  }
}
