import 'package:flutter/foundation.dart';
import '../domain/models/signature_result_model.dart';
import '../domain/repositories/rsa_demo_contract_signing_repository.dart';

class PdfCorruptionTestUtil {
  static Future<bool> testCorruption(
    RsaDemoContractSigningRepository repository,
    SignatureResultModel originalResult,
  ) async {
    // 1. Sao chép byte PDF
    final corruptedBytes = Uint8List.fromList(originalResult.pdfBytes);

    // 2. Sửa một byte bất kỳ (ví dụ ở giữa file)
    if (corruptedBytes.isNotEmpty) {
      final middleIndex = corruptedBytes.length ~/ 2;
      // Thay đổi giá trị byte
      corruptedBytes[middleIndex] = corruptedBytes[middleIndex] == 255 ? 0 : corruptedBytes[middleIndex] + 1;
    }

    // 3. Tạo một kết quả giả mạo chứa file đã bị sửa
    final corruptedResult = SignatureResultModel(
      contractId: originalResult.contractId,
      pdfBytes: corruptedBytes,
      pdfSha256: originalResult.pdfSha256, // Hash cũ hoặc mới đều được vì verify sẽ tính lại
      signaturePngBytes: originalResult.signaturePngBytes,
      signerName: originalResult.signerName,
      signedAt: originalResult.signedAt,
      publicKey: originalResult.publicKey,
      nonce: originalResult.nonce,
      signedMessage: originalResult.signedMessage,
      cryptographicSignature: originalResult.cryptographicSignature,
      isVerified: true,
    );

    // 4. Tính lại hash và xác minh với chữ ký cũ
    try {
      final isVerified = await repository.verifySignature(corruptedResult);
      if (isVerified) {
        debugPrint('CẢNH BÁO: Lỗi bảo mật. PDF bị sửa nhưng vẫn xác minh thành công.');
        return false;
      } else {
        debugPrint('THÀNH CÔNG: Chữ ký số phát hiện PDF bị sửa (xác minh thất bại đúng như dự kiến).');
        return true;
      }
    } catch (e) {
      debugPrint('THÀNH CÔNG: Chữ ký số phát hiện PDF bị sửa (văng lỗi: $e).');
      return true;
    }
  }
}
