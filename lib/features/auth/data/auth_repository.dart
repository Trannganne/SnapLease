import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {
          'tenDangNhap': username,
          'matKhau': password,
        },
      );
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response?.statusCode == 400) {
          throw Exception(e.response?.data['loi'] ?? 'Thông tin đăng nhập không hợp lệ.');
        } else if (e.response?.statusCode == 401) {
          throw Exception('Sai mật khẩu hoặc tài khoản không tồn tại.');
        }
      }
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError) {
        throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
      }
      throw Exception('Đã xảy ra lỗi hệ thống, vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String phone, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'tenDangNhap': username,
          'email': email,
          'soDienThoai': phone,
          'matKhau': password,
        },
      );
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response?.statusCode == 400 || e.response?.statusCode == 409) {
          throw Exception(e.response?.data['loi'] ?? 'Đã xảy ra lỗi, vui lòng thử lại.');
        }
      }
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError) {
        throw Exception('Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.');
      }
      throw Exception('Đã xảy ra lỗi hệ thống, vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }
}
