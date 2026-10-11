import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';


class DioContractSigningRepository implements ContractSigningRepository {
  final Dio _dio = ApiClient.instance;

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
        data: {
          'daDongYDieuKhoan': daDongYDieuKhoan,
        },
      );

      final data = otpResponse.data;
      return OtpRequestResult(
        maXacNhan: data['maXacNhan'],
        emailMask: data['emailMask'],
        expiredAt: DateTime.parse(data['hetHanLuc']),
      );
    } on DioException catch (e) {
      final req = e.requestOptions;
      final res = e.response;
      
      // Log for upload error
      print('=== UPLOAD ERROR ===');
      print('Method: ${req.method}');
      print('Path: ${req.path}');
      print('Status: ${res?.statusCode}');
      print('Content-Type: ${req.headers['Content-Type']}');
      print('Bytes size: ${pdfBytes.length}');
      print('Business code: ${res?.data?['code'] ?? 'N/A'}');
      print('TraceId: ${res?.headers.value('trace-id') ?? res?.headers.value('x-trace-id') ?? 'N/A'}');
      print('====================');

      final message = res?.data?['loi'] ?? 'Lỗi kết nối khi yêu cầu OTP.';
      throw message;
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
      if (data != null && data['trangThai'] != null) {
        return contract.copyWith(status: data['trangThai']);
      }

      final contractRes = await _dio.get('/api/hop-dong/${contract.contractId}');
      final contractData = contractRes.data;
      return contract.copyWith(
        status: contractData != null ? contractData['trangThai'] : contract.status,
      );
    } on DioException catch (e) {
      final message = e.response?.data?['loi'] ?? 'Lỗi kết nối khi xác nhận OTP.';
      throw message;
    } catch (e) {
      throw 'Lỗi không xác định: $e';
    }
  }
}
