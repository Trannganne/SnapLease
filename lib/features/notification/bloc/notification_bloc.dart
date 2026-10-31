import 'dart:math';
import 'dart:async';
import '../../../core/storage/token_storage.dart';
import '../data/push_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/notification_repository.dart';
import '../domain/models/notification_item_model.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;
  int _requestId = 0;
  StreamSubscription<void>? _session;
  StreamSubscription<void>? _push;
  @override
  Future<void> close() {
    ++_requestId;
    _session?.cancel();
    _push?.cancel();
    return super.close();
  }

  NotificationBloc({required NotificationRepository repository})
    : _repository = repository,
      super(const NotificationState()) {
    on<NotificationLoadStarted>(_onLoadStarted);
    on<NotificationCategoryChanged>(_onCategoryChanged);
    on<NotificationLoadMore>(_onLoadMore);
    on<NotificationMarkAsRead>(_onMarkAsRead);
    on<NotificationItemReadSynced>(_onItemReadSynced);
    _session = TokenStorage.changes.listen((_) {
      ++_requestId;
      add(const NotificationSessionChanged());
    });
    _push = PushService.instance.updates.stream.listen(
      (_) => add(const NotificationLoadStarted(isRefresh: true)),
    );
    on<NotificationSessionChanged>((event, emit) {
      emit(const NotificationState());
      add(const NotificationLoadStarted());
    });
  }

  void _onItemReadSynced(
    NotificationItemReadSynced event,
    Emitter<NotificationState> emit,
  ) {
    final itemIndex = state.items.indexWhere((e) => e.id == event.id);
    if (itemIndex == -1 || state.items[itemIndex].isRead) return;

    final updatedItems = List<NotificationItemModel>.from(state.items);
    updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(isRead: true);
    final newUnreadCount = max(0, state.totalUnreadCount - 1);
    final unreadView = state.selectedCategory == NotificationCategory.unread;
    emit(
      state.copyWith(
        items:
            unreadView
                ? updatedItems.where((i) => !i.isRead).toList()
                : updatedItems,
        totalCount:
            unreadView ? max(0, state.totalCount - 1) : state.totalCount,
        totalUnreadCount: newUnreadCount,
      ),
    );
    // Removing an unread row shifts server page offsets; reload before paging further.
    if (unreadView) add(const NotificationLoadStarted(isRefresh: true));
  }

  Future<void> _onLoadStarted(
    NotificationLoadStarted event,
    Emitter<NotificationState> emit,
  ) async {
    final currentReq = ++_requestId;

    if (event.isRefresh) {
      emit(state.copyWith(isRefreshing: true, clearUserNotice: true));
    } else {
      emit(
        state.copyWith(
          status: NotificationStatus.loading,
          clearUserNotice: true,
        ),
      );
    }

    try {
      final daDoc =
          state.selectedCategory == NotificationCategory.unread ? false : null;

      final results = await Future.wait([
        _repository.getNotifications(
          category: state.selectedCategory,
          daDoc: daDoc,
          page: 1,
          pageSize: 20,
        ),
        _repository.getTotalUnreadCount(),
      ]);

      if (currentReq != _requestId) return;

      final pageRes = results[0] as NotificationPageResult;
      final unreadCount = results[1] as int;

      final totalCount =
          state.selectedCategory == NotificationCategory.unread
              ? unreadCount
              : pageRes.totalCount;

      final hasReachedMax =
          pageRes.items.length >= pageRes.totalCount || pageRes.items.isEmpty;

      emit(
        state.copyWith(
          status: NotificationStatus.success,
          isRefreshing: false,
          items: pageRes.items,
          totalCount: totalCount,
          totalUnreadCount: unreadCount,
          currentPage: 1,
          hasReachedMax: hasReachedMax,
          loadMoreStatus: NotificationLoadMoreStatus.idle,
          clearUserNotice: true,
        ),
      );
    } catch (e) {
      if (currentReq != _requestId) return;

      if (event.isRefresh) {
        // Keep existing items, do not replace screen with error
        emit(
          state.copyWith(
            isRefreshing: false,
            userNotice: 'Không thể làm mới thông báo. Vui lòng thử lại.',
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: NotificationStatus.failure,
            errorMessage: 'Không thể tải danh sách thông báo.',
          ),
        );
      }
    }
  }

  Future<void> _onCategoryChanged(
    NotificationCategoryChanged event,
    Emitter<NotificationState> emit,
  ) async {
    if (event.category == state.selectedCategory) return;

    final currentReq = ++_requestId;

    emit(
      state.copyWith(
        selectedCategory: event.category,
        status: NotificationStatus.loading,
        currentPage: 1,
        hasReachedMax: false,
        clearUserNotice: true,
      ),
    );

    try {
      final daDoc =
          event.category == NotificationCategory.unread ? false : null;

      final results = await Future.wait([
        _repository.getNotifications(
          category: event.category,
          daDoc: daDoc,
          page: 1,
          pageSize: 20,
        ),
        _repository.getTotalUnreadCount(),
      ]);

      if (currentReq != _requestId) return;

      final pageRes = results[0] as NotificationPageResult;
      final unreadCount = results[1] as int;

      final totalCount =
          event.category == NotificationCategory.unread
              ? unreadCount
              : pageRes.totalCount;

      final hasReachedMax =
          pageRes.items.length >= pageRes.totalCount || pageRes.items.isEmpty;

      emit(
        state.copyWith(
          status: NotificationStatus.success,
          items: pageRes.items,
          totalCount: totalCount,
          totalUnreadCount: unreadCount,
          currentPage: 1,
          hasReachedMax: hasReachedMax,
          loadMoreStatus: NotificationLoadMoreStatus.idle,
          clearUserNotice: true,
        ),
      );
    } catch (e) {
      if (currentReq != _requestId) return;

      emit(
        state.copyWith(
          status: NotificationStatus.failure,
          errorMessage: 'Không thể tải danh sách thông báo.',
        ),
      );
    }
  }

  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (state.hasReachedMax ||
        state.loadMoreStatus == NotificationLoadMoreStatus.loading ||
        state.isRefreshing ||
        state.status != NotificationStatus.success) {
      return;
    }

    emit(
      state.copyWith(
        loadMoreStatus: NotificationLoadMoreStatus.loading,
        clearUserNotice: true,
      ),
    );

    final nextPage = state.currentPage + 1;
    final currentReq = ++_requestId;

    try {
      final daDoc =
          state.selectedCategory == NotificationCategory.unread ? false : null;

      final pageRes = await _repository.getNotifications(
        category: state.selectedCategory,
        daDoc: daDoc,
        page: nextPage,
        pageSize: 20,
      );

      if (currentReq != _requestId) return;

      // Deduplicate items to prevent duplicate keys
      final existingIds = state.items.map((e) => e.id).toSet();
      final newItems =
          pageRes.items.where((e) => !existingIds.contains(e.id)).toList();
      final combined = [...state.items, ...newItems];

      final hasReachedMax =
          combined.length >= pageRes.totalCount || pageRes.items.isEmpty;

      emit(
        state.copyWith(
          loadMoreStatus: NotificationLoadMoreStatus.idle,
          items: combined,
          totalCount: pageRes.totalCount,
          currentPage: nextPage,
          hasReachedMax: hasReachedMax,
          clearUserNotice: true,
        ),
      );
    } catch (e) {
      if (currentReq != _requestId) return;

      emit(
        state.copyWith(
          loadMoreStatus: NotificationLoadMoreStatus.error,
          userNotice: 'Không thể tải thêm thông báo.',
        ),
      );
    }
  }

  Future<void> _onMarkAsRead(
    NotificationMarkAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final itemIndex = state.items.indexWhere((e) => e.id == event.id);
    if (itemIndex == -1 || state.items[itemIndex].isRead) return;
    final request = _requestId;
    try {
      await _repository.markAsRead(event.id);
      if (isClosed || request != _requestId) return;
      _onItemReadSynced(NotificationItemReadSynced(event.id), emit);
    } catch (e) {
      if (isClosed || request != _requestId) return;
      emit(
        state.copyWith(
          userNotice: 'Không thể đánh dấu đã đọc. Vui lòng thử lại.',
        ),
      );
    }
  }
}
