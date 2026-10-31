import '../domain/models/notification_item_model.dart';

abstract class NotificationEvent {
  const NotificationEvent();
}

class NotificationSessionChanged extends NotificationEvent {
  const NotificationSessionChanged();
}

class NotificationLoadStarted extends NotificationEvent {
  final bool isRefresh;

  const NotificationLoadStarted({this.isRefresh = false});
}

class NotificationCategoryChanged extends NotificationEvent {
  final NotificationCategory category;

  const NotificationCategoryChanged(this.category);
}

class NotificationLoadMore extends NotificationEvent {
  const NotificationLoadMore();
}

class NotificationMarkAsRead extends NotificationEvent {
  final String id;

  const NotificationMarkAsRead(this.id);
}

class NotificationItemReadSynced extends NotificationEvent {
  final String id;

  const NotificationItemReadSynced(this.id);
}
