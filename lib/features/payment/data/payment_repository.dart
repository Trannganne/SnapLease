import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../domain/models/payment_model.dart';

class PaymentRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<PaymentModel>> getPayments(String contractId) async {
    try {
      final response = await _dio.get('/api/hop-dong/$contractId/thanh-toan');
      final data = response.data as List;
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách thanh toán: $e');
    }
  }

  Future<PaymentModel> createDepositPayment(String contractId, String phuongThuc) async {
    try {
      final response = await _dio.post(
        '/api/hop-dong/$contractId/thanh-toan-coc',
        data: {
          'phuongThuc': phuongThuc,
          'noiDungChuyenKhoan': '',
        },
      );
      return PaymentModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw Exception(e.response?.data['loi'] ?? 'Khoản thanh toán cọc đã tồn tại.');
      }
      throw Exception('Lỗi khi tạo thanh toán: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi khi tạo thanh toán: $e');
    }
  }
}
