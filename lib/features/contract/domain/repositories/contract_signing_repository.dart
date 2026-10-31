import 'dart:typed_data';
import '../../services/contract_pdf_service.dart';

class OtpRequestResult {
  final String maXacNhan;
  final String emailMask;
  final DateTime expiredAt;

  OtpRequestResult({
    required this.maXacNhan,
    required this.emailMask,
    required this.expiredAt,
  });
}

abstract class ContractSigningRepository {
  Future<OtpRequestResult> uploadPdfAndRequestOtp(
    ContractModel contract,
    Uint8List pdfBytes,
    bool daDongYDieuKhoan,
  );

  Future<ContractModel> verifyOtp(
    ContractModel contract,
    String maXacNhan,
    String otp,
    bool daDongYDieuKhoan,
  );
}
