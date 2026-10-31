import '../domain/models/notification_item_model.dart';

enum NotificationStatus {
  initial,
  loading,
  success,
  failure,
}

enum NotificationLoadMoreStatus {
  idle,
  loading,
  error,
}

class NotificationState {
  final NotificationStatus status;
  final bool isRefreshing;
  final NotificationLoadMoreStatus loadMoreStatus;
  final NotificationCategory selectedCategory;
  final List<NotificationItemModel> items;
  final int totalCount;
  final int totalUnreadCount;
  final int currentPage;
  final bool hasReachedMax;
  final String? errorMessage;
  final String? userNotice;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.isRefreshing = false,
    this.loadMoreStatus = NotificationLoadMoreStatus.idle,
    this.selectedCategory = NotificationCategory.all,
    this.items = const [],
    this.totalCount = 0,
    this.totalUnreadCount = 0,
    this.currentPage = 1,
    this.hasReachedMax = false,
    this.errorMessage,
    this.userNotice,
  });

  NotificationState copyWith({
    NotificationStatus? status,
    bool? isRefreshing,
    NotificationLoadMoreStatus? loadMoreStatus,
    NotificationCategory? selectedCategory,
    List<NotificationItemModel>? items,
    int? totalCount,
    int? totalUnreadCount,
    int? currentPage,
    bool? hasReachedMax,
    String? errorMessage,
    String? userNotice,
    bool clearUserNotice = false,
  }) {
    return NotificationState(
      status: status ?? this.status,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadMoreStatus: loadMoreStatus ?? this.loadMoreStatus,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      currentPage: currentPage ?? this.currentPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: errorMessage ?? this.errorMessage,
      userNotice: clearUserNotice ? null : (userNotice ?? this.userNotice),
    );
  }

  /// Filtered items based on selected category
  List<NotificationItemModel> get filteredItems {
    return items.where((item) => item.matchesCategory(selectedCategory)).toList();
  }

  /// Group items by date: HÔM NAY, HÔM QUA, TRƯỚC ĐÓ
  NotificationDateGroups get dateGroups {
    final now = DateTime.now();
    final today = <NotificationItemModel>[];
    final yesterday = <NotificationItemModel>[];
    final earlier = <NotificationItemModel>[];

    for (var item in filteredItems) {
      if (_isSameDay(item.sentAt, now)) {
        today.add(item);
      } else if (_isSameDay(
          item.sentAt, now.subtract(const Duration(days: 1)))) {
        yesterday.add(item);
      } else {
        earlier.add(item);
      }
    }

    return NotificationDateGroups(
      today: today,
      yesterday: yesterday,
      earlier: earlier,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class NotificationDateGroups {
  final List<NotificationItemModel> today;
  final List<NotificationItemModel> yesterday;
  final List<NotificationItemModel> earlier;

  const NotificationDateGroups({
    required this.today,
    required this.yesterday,
    required this.earlier,
  });

  int get todayUnread => today.where((e) => !e.isRead).length;
  int get yesterdayUnread => yesterday.where((e) => !e.isRead).length;
  int get earlierUnread => earlier.where((e) => !e.isRead).length;

  bool get isEmpty => today.isEmpty && yesterday.isEmpty && earlier.isEmpty;
}
