import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/storage/token_storage.dart';
import '../../../domain/entities/branch.dart';
import '../../branches/domain/branch_repository.dart';
import '../domain/chat_models.dart';
import '../domain/chat_repository.dart';

class ChatAvailabilityState {
  final List<Branch> branches;
  final String? selectedId, error;
  final DateTime? start, end, checkedAt;
  final int? count;
  final bool loading, checking;
  const ChatAvailabilityState({
    this.branches = const [],
    this.selectedId,
    this.error,
    this.start,
    this.end,
    this.checkedAt,
    this.count,
    this.loading = false,
    this.checking = false,
  });
}

class ChatAvailabilityCubit extends Cubit<ChatAvailabilityState> {
  final BranchRepository branches;
  final ChatRepository repository;
  final String productId;
  CancelToken _cancel = CancelToken();
  int _version = 0;
  late final StreamSubscription<void> _session;
  ChatAvailabilityCubit({
    required this.branches,
    required this.repository,
    required this.productId,
  }) : super(const ChatAvailabilityState()) {
    _session = TokenStorage.willChange.listen((_) {
      _version++;
      _cancel.cancel();
      if (!isClosed) {
        emit(
          const ChatAvailabilityState(
            error: 'Phiên đăng nhập đã thay đổi. Hãy mở lại màn kiểm tra.',
          ),
        );
      }
    });
  }
  Future<void> load() async {
    final version = ++_version;
    emit(const ChatAvailabilityState(loading: true));
    try {
      final rows = await branches.getBranches();
      if (!isClosed && version == _version) {
        emit(ChatAvailabilityState(branches: rows));
      }
    } catch (_) {
      if (!isClosed && version == _version) {
        emit(
          const ChatAvailabilityState(
            error: 'Không tải được danh sách chi nhánh.',
          ),
        );
      }
    }
  }

  void select(String id) {
    if (!state.branches.any((b) => b.id == id)) return;
    _version++;
    _cancel.cancel();
    _cancel = CancelToken();
    emit(ChatAvailabilityState(branches: state.branches, selectedId: id));
  }

  Future<void> check(DateTime start, DateTime end) async {
    final id = state.selectedId;
    if (id == null || state.checking) return;
    if (!end.isAfter(start) || start.isUtc || end.isUtc) {
      emit(
        ChatAvailabilityState(
          branches: state.branches,
          selectedId: id,
          error: 'Chọn khoảng giờ nhận/trả địa phương hợp lệ.',
        ),
      );
      return;
    }
    final version = ++_version;
    emit(
      ChatAvailabilityState(
        branches: state.branches,
        selectedId: id,
        start: start,
        end: end,
        checking: true,
      ),
    );
    try {
      final count = await repository.availability(
        productId,
        id,
        start,
        end,
        _cancel,
      );
      if (!isClosed && version == _version) {
        emit(
          ChatAvailabilityState(
            branches: state.branches,
            selectedId: id,
            start: start,
            end: end,
            count: count,
            checkedAt: DateTime.now(),
          ),
        );
      }
    } catch (error) {
      if (!isClosed && version == _version) {
        emit(
          ChatAvailabilityState(
            branches: state.branches,
            selectedId: id,
            start: start,
            end: end,
            error:
                error is ChatFailure
                    ? error.message
                    : 'Chưa xác định được lịch trống.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _version++;
    _cancel.cancel();
    await _session.cancel();
    await super.close();
  }
}
