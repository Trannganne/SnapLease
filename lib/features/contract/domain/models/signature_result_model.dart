import 'dart:typed_data';

class SignatureResultModel {
  final String contractId;
  final Uint8List pdfBytes;
  final String pdfSha256;
  final Uint8List signaturePngBytes;
  final String signerName;
  final DateTime signedAt;
  final String publicKey;
  final String nonce;
  final String signedMessage;
  final String cryptographicSignature;
  final bool isVerified;

  SignatureResultModel({
    required this.contractId,
    required this.pdfBytes,
    required this.pdfSha256,
    required this.signaturePngBytes,
    required this.signerName,
    required this.signedAt,
    required this.publicKey,
    required this.nonce,
    required this.signedMessage,
    required this.cryptographicSignature,
    required this.isVerified,
  });
}
