import 'dart:typed_data';
import '../models/signature_result_model.dart';
import '../../services/contract_pdf_service.dart';

abstract class RsaDemoContractSigningRepository {
  Future<SignatureResultModel> signContract(
    ContractModel contract,
    Uint8List signaturePngBytes,
  );

  Future<bool> verifySignature(SignatureResultModel result);
}
