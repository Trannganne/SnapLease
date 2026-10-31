import 'package:dio/dio.dart';
import 'dart:io' show HttpDate;
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<void> requestEmailVerification() async {
    final generation = TokenStorage.generation;
    final token = await TokenStorage.getToken();
    if (token == null ||
        TokenStorage.isChanging ||
        generation != TokenStorage.generation) {
      throw const PasswordRecoveryFailure(
        RecoveryFailureKind.authenticationRequired,
      );
    }
    await _passwordRequest(
      '/api/auth/email/xac-minh/gui',
      null,
      expectedStatus: 202,
      sessionToken: token,
    );
  }

  Future<void> verifyEmail(String token) => _passwordRequest(
    '/api/auth/email/xac-minh',
    {'token': token},
    expectedStatus: 204,
  );

  Future<void> requestPasswordRecovery(String email) async {
    await _passwordRequest('/api/auth/quen-mat-khau', {
      'emailHoacSoDienThoai': email.trim(),
    }, expectedStatus: 202);
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _passwordRequest('/api/auth/dat-lai-mat-khau', {
      'resetToken': resetToken,
      'matKhauMoi': newPassword,
    }, expectedStatus: 204);
  }

  Future<void> _passwordRequest(
    String path,
    Map<String, String>? data, {
    required int expectedStatus,
    String? sessionToken,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(
          extra: {ApiClient.boundSession: true},
          headers:
              sessionToken == null
                  ? null
                  : {'Authorization': 'Bearer $sessionToken'},
        ),
      );
      if (response.statusCode != expectedStatus) {
        throw const PasswordRecoveryFailure(
          RecoveryFailureKind.unknown,
          uncertain: true,
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && sessionToken != null) {
        throw const PasswordRecoveryFailure(
          RecoveryFailureKind.authenticationRequired,
        );
      }
      if (status == 400 &&
          e.response?.data is Map &&
          e.response?.data['code'] == 'EMAIL_REQUIRED') {
        throw const PasswordRecoveryFailure(RecoveryFailureKind.emailRequired);
      }
      if (status == 409 &&
          e.response?.data is Map &&
          e.response?.data['code'] == 'VERIFIED_EMAIL_ALREADY_USED') {
        throw const PasswordRecoveryFailure(RecoveryFailureKind.emailConflict);
      }
      if (status == 429) {
        DateTime? retryAt;
        final value = e.response?.headers.value('retry-after');
        if (value != null) {
          final seconds = int.tryParse(value);
          if (seconds != null && seconds >= 0) {
            retryAt = DateTime.now().toUtc().add(Duration(seconds: seconds));
          } else {
            try {
              retryAt = HttpDate.parse(value).toUtc();
            } catch (_) {}
          }
        }
        throw PasswordRecoveryFailure(
          RecoveryFailureKind.rateLimited,
          retryAt: retryAt,
        );
      }
      if (status == 400 &&
          e.response?.data is Map &&
          e.response?.data['code'] == 'INVALID_AUTH_LINK') {
        throw const PasswordRecoveryFailure(RecoveryFailureKind.invalidLink);
      }
      if (status == 400) {
        throw const PasswordRecoveryFailure(RecoveryFailureKind.validation);
      }
      if (e.response == null) {
        throw const PasswordRecoveryFailure(
          RecoveryFailureKind.network,
          uncertain: true,
        );
      }
      throw PasswordRecoveryFailure(
        RecoveryFailureKind.unknown,
        uncertain: status != null && status >= 500,
      );
    }
  }

  Future<Map<String, dynamic>> getMe({required String sessionToken}) async {
    final response = await _dio.get(
      '/api/auth/me',
      options: Options(
        headers: {'Authorization': 'Bearer $sessionToken'},
        extra: {ApiClient.boundSession: true},
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'tenDangNhap': username, 'matKhau': password},
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response != null) {
        if (e.response?.statusCode == 400) {
          throw Exception(
            e.response?.data['loi'] ?? 'Thông tin đăng nhập không hợp lệ.',
          );
        } else if (e.response?.statusCode == 401) {
          throw Exception('Sai mật khẩu hoặc tài khoản không tồn tại.');
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
        );
      }
      throw Exception('Đã xảy ra lỗi hệ thống, vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String phone,
    String password,
  ) async {
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
          throw Exception(
            e.response?.data['loi'] ?? 'Đã xảy ra lỗi, vui lòng thử lại.',
          );
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng.',
        );
      }
      throw Exception('Đã xảy ra lỗi hệ thống, vui lòng thử lại.');
    } catch (e) {
      throw Exception('Lỗi không xác định: $e');
    }
  }
}

enum RecoveryFailureKind {
  authenticationRequired,
  emailRequired,
  emailConflict,
  rateLimited,
  invalidLink,
  validation,
  network,
  unknown,
}

class PasswordRecoveryFailure implements Exception {
  final RecoveryFailureKind kind;
  final DateTime? retryAt;
  final bool uncertain;
  const PasswordRecoveryFailure(
    this.kind, {
    this.retryAt,
    this.uncertain = false,
  });
  @override
  String toString() => 'PasswordRecoveryFailure(${kind.name})';
}
