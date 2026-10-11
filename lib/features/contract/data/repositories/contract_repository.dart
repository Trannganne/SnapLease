import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class ContractRepository {
  final Dio _dio;

  ContractRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<Map<String, dynamic>> getContractById(String contractId) async {
    try {
      final response = await _dio.get('/api/hop-dong/$contractId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map && e.response!.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi tải hợp đồng.');
    }
  }

  Future<void> cancelContract(String contractId) async {
    try {
      await _dio.post('/api/hop-dong/$contractId/huy');
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map && e.response!.data['loi'] != null) {
        throw Exception(e.response!.data['loi']);
      }
      throw Exception('Lỗi hệ thống khi hủy hợp đồng.');
    }
  }
}
