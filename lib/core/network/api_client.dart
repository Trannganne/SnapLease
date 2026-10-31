import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'api_config.dart';

class ApiClient {
  // Background cleanup belongs to the captured old session. It must neither
  // borrow a newer credential nor invalidate a session after a late 401.
  static const sessionCleanup = 'sessionCleanup';
  // Profile/identity work stays bound to the session that started it.
  static const boundSession = 'boundSession';

  static final Dio _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    )
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra[sessionCleanup] != true &&
              options.extra[boundSession] != true) {
            final token = await TokenStorage.getToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // schema33-v2/security-epoch changes invalidate older Bearer tokens.
          // A late 401 must never log out a newer session or retry the request.
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra[sessionCleanup] != true &&
              !TokenStorage.isChanging) {
            final token = await TokenStorage.getToken();
            if (token != null &&
                error.requestOptions.headers['Authorization'] ==
                    'Bearer $token') {
              try {
                await TokenStorage.deleteToken();
              } catch (_) {
                // Preserve the original API failure if local cleanup fails.
              }
            }
          }
          handler.next(error);
        },
      ),
    );

  static Dio get instance => _dio;
}
