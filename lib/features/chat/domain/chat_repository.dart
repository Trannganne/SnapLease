import 'package:dio/dio.dart';
import 'chat_models.dart';

abstract interface class ChatRepository {
  Future<String> account(CancelToken cancel);
  Future<ChatStatus> status(CancelToken cancel);
  Future<ChatMessage> send(
    String text,
    List<ChatMessage> history,
    CancelToken cancel,
  );
  Future<int> availability(
    String productId,
    String branchId,
    DateTime start,
    DateTime end,
    CancelToken cancel,
  );
}
