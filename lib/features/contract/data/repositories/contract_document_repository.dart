import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../services/contract_pdf_service.dart';

class ContractDocumentRepository {
  final Dio _dio;
  final ContractPdfService _pdfService;

  ContractDocumentRepository({Dio? dio, ContractPdfService? pdfService})
    : _dio = dio ?? ApiClient.instance,
      _pdfService = pdfService ?? ContractPdfService();

  Future<Uint8List> load(ContractModel contract) async {
    if (!contract.requiresSignedPdf) {
      return _pdfService.generateContractPdf(contract);
    }
    if (contract.signedPdfAvailable == false) {
      throw Exception('Chưa có bản hợp đồng đã ký.');
    }
    // Persisted signed contracts always use the Backend PDF endpoint, which
    // checks its stored hash. Never regenerate a substitute signed document.
    final local = contract.signatureResult?.pdfBytes;
    if (contract.status == 'CHO_KY' && local != null) {
      return _validated(local);
    }
    try {
      final response = await _dio.get<List<int>>(
        '/api/hop-dong/${Uri.encodeComponent(contract.contractId)}/tep-pdf',
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );
      return _validated(response.data);
    } on DioException {
      throw Exception('Không thể tải PDF đã ký. Vui lòng thử lại.');
    }
  }

  Uint8List _validated(List<int>? bytes) {
    if (bytes == null ||
        bytes.length < 5 ||
        bytes[0] != 37 ||
        bytes[1] != 80 ||
        bytes[2] != 68 ||
        bytes[3] != 70 ||
        bytes[4] != 45) {
      throw Exception('Dữ liệu PDF đã ký không hợp lệ.');
    }
    return Uint8List.fromList(bytes);
  }
}
