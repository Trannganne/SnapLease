import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:math';

import '../../domain/models/signature_result_model.dart';
import '../../domain/repositories/rsa_demo_contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';
import '../services/crypto_service.dart';

class MockContractSigningRepository implements RsaDemoContractSigningRepository {
  final ContractPdfService _pdfService = ContractPdfService();
  final CryptoService _cryptoService = CryptoService();

  @override
  Future<SignatureResultModel> signContract(
    ContractModel contract,
    Uint8List signaturePngBytes,
  ) async {
    // 1. Generate PDF with signature image
    final pdfBytes = await _pdfService.generateContractPdf(
      contract,
      signaturePngBytes: signaturePngBytes,
    );

    // 2. Hash the PDF bytes
    final pdfSha256 = sha256.convert(pdfBytes).toString();

    // 3. Generate Nonce
    final nonce = DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(10000).toString();

    // 4. Construct message to sign
    final signedMessage = '${contract.contractId}|$pdfSha256|$nonce';

    // 5. Generate Key Pair and Sign
    final keyAlias = 'rentcam_demo_key_${contract.contractId}';
    final publicKey = await _cryptoService.generateKeyPair(keyAlias);
    final cryptographicSignature = await _cryptoService.signData(keyAlias, signedMessage);

    // 6. Verify immediately for demonstration
    final isVerified = await _cryptoService.verifySignature(keyAlias, signedMessage, cryptographicSignature);

    return SignatureResultModel(
      contractId: contract.contractId,
      pdfBytes: pdfBytes,
      pdfSha256: pdfSha256,
      signaturePngBytes: signaturePngBytes,
      signerName: contract.lesseeName,
      signedAt: DateTime.now(),
      publicKey: publicKey,
      nonce: nonce,
      signedMessage: signedMessage,
      cryptographicSignature: cryptographicSignature,
      isVerified: isVerified,
    );
  }

  @override
  Future<bool> verifySignature(SignatureResultModel result) async {
    final keyAlias = 'rentcam_demo_key_${result.contractId}';
    
    // Re-hash current pdfBytes to detect corruption
    final currentPdfSha256 = sha256.convert(result.pdfBytes).toString();
    final messageToVerify = '${result.contractId}|$currentPdfSha256|${result.nonce}';

    return await _cryptoService.verifySignature(
      keyAlias,
      messageToVerify,
      result.cryptographicSignature,
    );
  }
}
