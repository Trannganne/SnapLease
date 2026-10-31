import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

class DioChatRepository implements ChatRepository {
  final Dio dio;
  DioChatRepository({Dio? dio}) : dio = dio ?? ApiClient.instance;
  @override
  Future<String> account(CancelToken cancel) async {
    if (TokenStorage.isChanging) {
      throw const ChatFailure(
        'Phiên đăng nhập đang thay đổi. Vui lòng mở lại trợ lý.',
      );
    }
    final generation = TokenStorage.generation;
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw const ChatFailure('Vui lòng đăng nhập để dùng trợ lý.');
    }
    final cached = await TokenStorage.getAccountId();
    if (cached != null &&
        !TokenStorage.isChanging &&
        generation == TokenStorage.generation) {
      return cached;
    }
    final response = await dio.get('/api/auth/me', cancelToken: cancel);
    final data = response.data;
    final id = data is Map ? data['maTaiKhoan'] : null;
    if (id is! String ||
        id.isEmpty ||
        !await TokenStorage.bindAccount(token, id, generation)) {
      throw const ChatFailure('Phiên đăng nhập đã thay đổi.');
    }
    return id;
  }

  @override
  Future<ChatStatus> status(CancelToken cancel) async {
    try {
      final response = await dio.get(
        '/api/tro-ly/trang-thai',
        cancelToken: cancel,
      );
      final data = response.data;
      if (data is! Map || data['enabled'] is! bool) {
        throw const FormatException();
      }
      return ChatStatus(data['enabled'] as bool, data['reason'] as String?);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return const ChatStatus(false, 'Máy chủ chưa triển khai trợ lý AI.');
      }
      throw _failure(error);
    }
  }

  @override
  Future<ChatMessage> send(
    String text,
    List<ChatMessage> history,
    CancelToken cancel,
  ) async {
    try {
      final response = await dio.post(
        '/api/tro-ly/tin-nhan',
        data: {
          'message': text,
          'history':
              history
                  .where((m) => m.role == 'user')
                  .toList()
                  .reversed
                  .take(3)
                  .toList()
                  .reversed
                  .map((m) => {'role': m.role, 'text': m.text})
                  .toList(),
        },
        cancelToken: cancel,
        options: Options(receiveTimeout: const Duration(seconds: 25)),
      );
      final data = response.data;
      if (data is! Map ||
          data['text'] is! String ||
          (data['text'] as String).trim().isEmpty ||
          data['products'] is! List ||
          data['sources'] is! List ||
          DateTime.tryParse(data['observedAtUtc'] as String? ?? '') == null) {
        throw const ChatFailure('AI chưa trả về câu trả lời hợp lệ.');
      }
      return ChatMessage(
        role: 'assistant',
        text: data['text'],
        at: DateTime.parse(data['observedAtUtc']).toUtc(),
        products:
            (data['products'] as List)
                .map(
                  (e) =>
                      ChatProduct.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList(),
        sources: (data['sources'] as List).cast<String>(),
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<int> availability(
    String productId,
    String branchId,
    DateTime start,
    DateTime end,
    CancelToken cancel,
  ) async {
    if (branchId.isEmpty || !end.isAfter(start) || start.isUtc || end.isUtc) {
      throw const ChatFailure('Cần chi nhánh và khoảng thời gian thuê hợp lệ.');
    }
    String local(DateTime time) =>
        time.toIso8601String().replaceFirst(RegExp(r'Z$'), '');
    try {
      final response = await dio.get(
        '/api/lich-trong',
        queryParameters: {
          'maDongMay': productId,
          'maCuaHang': branchId,
          'ngayBatDau': local(start),
          'ngayKetThuc': local(end),
        },
        cancelToken: cancel,
      );
      final data = response.data;
      final count = data is Map ? data['soLuongConTrong'] : null;
      final returnedStart =
          data is Map
              ? DateTime.tryParse(data['ngayBatDau'] as String? ?? '')
              : null;
      final returnedEnd =
          data is Map
              ? DateTime.tryParse(data['ngayKetThuc'] as String? ?? '')
              : null;
      if (data is! Map ||
          data['maDongMay'] != productId ||
          data['maCuaHang'] != branchId ||
          returnedStart != start ||
          returnedEnd != end ||
          count is! num ||
          !count.isFinite ||
          count < 0 ||
          count != count.toInt()) {
        throw const ChatFailure('Chưa xác định được lịch trống.');
      }
      return count.toInt();
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  ChatFailure _failure(DioException error) {
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      return const ChatFailure(
        'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.',
      );
    }
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionTimeout) {
      return const ChatFailure(
        'Phản hồi quá thời gian. Yêu cầu không được tự gửi lại.',
      );
    }
    if (error.response?.statusCode == 429) {
      return const ChatFailure(
        'Trợ lý đang giới hạn lượt hoặc hết hạn mức miễn phí. Hãy thử lại sau.',
      );
    }
    final body = error.response?.data;
    if (body is Map && body['loi'] is String) return ChatFailure(body['loi']);
    return const ChatFailure(
      'Không kết nối được trợ lý. Bạn vẫn có thể dùng các chức năng khác.',
    );
  }
}
