import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/models/review_form.dart';

class ReviewRemoteDataSource {
  final Dio dio;
  final Future<String?> Function() session;
  ReviewRemoteDataSource({Dio? dio, Future<String?> Function()? session})
    : dio = dio ?? ApiClient.instance,
      session = session ?? TokenStorage.getToken;

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    dynamic data,
  }) async {
    final identity = await session();
    if (identity == null) {
      throw const ReviewFailure('Vui lòng đăng nhập lại.', status: 401);
    }
    if (kDebugMode) {
      debugPrint('[ReviewApi] $method $path');
    }
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        options: Options(
          method: method,
          contentType:
              data is FormData ? 'multipart/form-data' : 'application/json',
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '[ReviewApi] $method $path -> ${response.statusCode ?? 200} OK',
        );
      }
      if (identity != await session()) {
        throw const ReviewFailure(
          'Phiên đăng nhập đã thay đổi. Hãy tải lại.',
          status: 401,
        );
      }
      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final message = body is Map ? body['loi'] ?? body['message'] : null;
      if (kDebugMode) {
        debugPrint(
          '[ReviewApi] $method $path -> HTTP $status: $message (${e.type})',
        );
      }
      if (identity != await session()) {
        throw const ReviewFailure(
          'Phiên đăng nhập đã thay đổi. Hãy tải lại.',
          status: 401,
        );
      }
      throw ReviewFailure(
        switch (status) {
          401 => 'Phiên đăng nhập đã hết hạn.',
          403 => 'Bạn không có quyền đánh giá thiết bị này.',
          404 => 'Không tìm thấy dữ liệu hoặc API Đánh giá chưa sẵn sàng.',
          _ =>
            message is String
                ? message
                : 'Không thể kết nối API Đánh giá. Vui lòng thử lại.',
        },
        status: status,
        uncertain:
            method == 'POST' &&
            (status == null || status == 408 || status >= 500),
      );
    }
  }

  Future<dynamic> upload(String id, String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const ReviewFailure('Ảnh đã chọn không còn tồn tại.');
    }
    final bytes = await file
        .openRead(0, 12)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    String? mime;
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      mime = 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      mime = 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      mime = 'image/webp';
    }
    if (mime == null || await file.length() == 0) {
      throw const ReviewFailure('Chỉ chấp nhận ảnh JPEG, PNG hoặc WEBP.');
    }
    // The form exposes count but no byte-size limit. The server enforces bytes.
    final form = FormData.fromMap({
      'anh': await MultipartFile.fromFile(
        path,
        contentType: MediaType.parse(mime),
      ),
    });
    return request(
      '/api/danh-gia/${Uri.encodeComponent(id)}/anh',
      method: 'POST',
      data: form,
    );
  }
}
