import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/token_storage.dart';
import '../data/chat_history_store.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool loading, sending, enabled;
  final String? error;
  const ChatState({
    this.messages = const [],
    this.loading = false,
    this.sending = false,
    this.enabled = false,
    this.error,
  });
}

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository repository;
  final ChatHistoryStore history;
  late final StreamSubscription<void> _session;
  CancelToken _cancel = CancelToken();
  String? _account;
  int _version = 0;
  int _sessionGeneration = TokenStorage.generation;
  ChatCubit({required this.repository, required this.history})
    : super(const ChatState()) {
    history.attach();
    _session = TokenStorage.willChange.listen((_) {
      _version++;
      _account = null;
      _cancel.cancel();
      if (!isClosed) {
        emit(
          const ChatState(
            error:
                'Phiên đăng nhập đã thay đổi. Hãy mở lại trợ lý sau khi đăng nhập.',
          ),
        );
      }
    });
  }
  bool _current(int version) =>
      !isClosed &&
      !TokenStorage.isChanging &&
      version == _version &&
      _sessionGeneration == TokenStorage.generation;
  Future<void> load() async {
    if (TokenStorage.isChanging) {
      emit(
        const ChatState(
          error: 'Phiên đăng nhập đang thay đổi. Vui lòng mở lại trợ lý.',
        ),
      );
      return;
    }
    final version = ++_version;
    _sessionGeneration = TokenStorage.generation;
    _cancel.cancel();
    _cancel = CancelToken();
    emit(const ChatState(loading: true));
    try {
      final account = await repository.account(_cancel);
      if (!_current(version)) return;
      _account = account;
      final messages = await history.load(account);
      if (!_current(version)) return;
      emit(ChatState(messages: messages, loading: true));
      final status = await repository.status(_cancel);
      if (_current(version)) {
        emit(
          ChatState(
            messages: messages,
            enabled: status.enabled,
            error: status.reason,
          ),
        );
      }
    } catch (error) {
      if (_current(version)) {
        emit(ChatState(messages: state.messages, error: _message(error)));
      }
    }
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (state.sending || !state.enabled || _account == null || text.isEmpty) {
      return;
    }
    if (text.length > 1200) {
      emit(
        ChatState(
          messages: state.messages,
          enabled: true,
          error: 'Tin nhắn tối đa 1.200 ký tự.',
        ),
      );
      return;
    }
    final version = _version;
    final prior = List<ChatMessage>.of(state.messages);
    final messages = [
      ...prior,
      ChatMessage(role: 'user', text: text, at: DateTime.now().toUtc()),
    ];
    emit(ChatState(messages: messages, sending: true, enabled: true));
    try {
      await history.save(_account!, messages, _sessionGeneration);
      if (!_current(version)) return;
      final reply = await repository.send(text, prior, _cancel);
      if (!_current(version)) return;
      final complete = [...messages, reply];
      await history.save(_account!, complete, _sessionGeneration);
      if (_current(version)) emit(ChatState(messages: complete, enabled: true));
    } catch (error) {
      if (_current(version)) {
        emit(
          ChatState(messages: messages, enabled: true, error: _message(error)),
        );
      }
    }
  }

  Future<void> clearHistory() async {
    final account = _account;
    if (account == null) return;
    final enabled = state.enabled;
    final version = ++_version;
    _cancel.cancel();
    _cancel = CancelToken();
    emit(ChatState(enabled: enabled, loading: true));
    try {
      await history.clear(account);
      if (_current(version)) emit(ChatState(enabled: enabled));
    } catch (_) {
      if (_current(version)) {
        emit(
          ChatState(
            enabled: enabled,
            error: 'Không xóa được lịch sử. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  String _message(Object error) =>
      error is ChatFailure
          ? error.message
          : 'Không xử lý được hội thoại. Vui lòng thử lại.';
  @override
  Future<void> close() async {
    _version++;
    _cancel.cancel();
    await _session.cancel();
    await super.close();
  }
}
