import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models/payment_model.dart';

class PaymentRepository {
  final Dio _dio;

  PaymentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  static bool _uncertain(DioException e) =>
      e.response?.statusCode == 408 ||
      (e.response?.statusCode ?? 0) >= 500 ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.unknown;

  static String _message(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      for (final key in ['loi', 'title', 'detail']) {
        if (data[key] is String && (data[key] as String).isNotEmpty) {
          return data[key] as String;
        }
      }
    }
    return fallback;
  }

  Future<List<PaymentModel>> getPayments(String contractId) async {
    try {
      final response = await _dio.get('/api/hop-dong/$contractId/thanh-toan');
      final data = response.data as List;
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách thanh toán: $e');
    }
  }

  Future<PaymentModel> createDepositPayment(
    String contractId,
    String phuongThuc,
  ) async {
    try {
      final response = await _dio.post(
        '/api/hop-dong/$contractId/thanh-toan-coc',
        data: {'phuongThuc': phuongThuc, 'noiDungChuyenKhoan': ''},
      );
      return PaymentModel.fromJson(response.data);
    } on DioException catch (e) {
      if (_uncertain(e)) {
        throw const PaymentRequestUncertain(
          'Chưa xác định kết quả tạo khoản cọc.',
        );
      }
      if (e.response?.statusCode == 409) {
        throw Exception(_message(e, 'Khoản thanh toán cọc đã tồn tại.'));
      }
      throw Exception('Lỗi khi tạo thanh toán: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi khi tạo thanh toán: $e');
    }
  }

  Future<PaymentModel> getPaymentById(String paymentId) async {
    try {
      final response = await _dio.get('/api/thanh-toan/$paymentId');
      return PaymentModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Lỗi khi tải chi tiết thanh toán: ${e.message}');
    } catch (e) {
      throw Exception('Lỗi khi tải chi tiết thanh toán: $e');
    }
  }

  Future<PaymentModel> createVnpayPaymentUrl(String paymentId) async {
    try {
      final response = await _dio.post('/api/thanh-toan/$paymentId/vnpay');
      return PaymentModel.fromJson(response.data);
    } on DioException catch (e) {
      if (_uncertain(e)) {
        throw const PaymentRequestUncertain(
          'Chưa xác định kết quả tạo liên kết VNPAY.',
        );
      }
      if (e.response?.statusCode == 409) {
        throw Exception(
          _message(e, 'Yêu cầu thanh toán VNPAY không hợp lệ hoặc đã hết hạn.'),
        );
      }
      throw Exception(_message(e, 'Không thể tạo liên kết VNPAY.'));
    } catch (e) {
      throw Exception('Lỗi khi tạo liên kết VNPAY: $e');
    }
  }

  Future<PaymentModel> reconcileVnpayPayment(String paymentId) async {
    bool attemptFailed = false;
    try {
      final response = await _dio.post(
        '/api/thanh-toan/$paymentId/vnpay/doi-soat',
      );
      final result = response.data;
      attemptFailed =
          result is Map &&
          result['maThanhToan'] == paymentId &&
          result['thanhCong'] == false &&
          result['trangThaiYeuCauVnpay'] == 'THAT_BAI';
    } on DioException catch (e) {
      // Unknown result or rate limit: read the persisted status, never infer success.
      if (!_uncertain(e) &&
          e.response?.statusCode != 409 &&
          e.response?.statusCode != 429) {
        throw Exception('Chưa thể đối soát VNPAY. Vui lòng kiểm tra lại.');
      }
    }
    final payment = await getPaymentById(paymentId);
    return attemptFailed && payment.trangThai == 'CHO_THANH_TOAN'
        ? payment.withFailedVnpayAttempt()
        : payment;
  }
}

class PaymentRequestUncertain implements Exception {
  final String message;
  const PaymentRequestUncertain(this.message);
  @override
  String toString() => message;
}
