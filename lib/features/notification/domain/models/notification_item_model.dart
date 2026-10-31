enum NotificationCategory { all, unread, contract, payment }

enum NotificationTargetType { none, contract, payment, reservation }

class NotificationItemModel {
  final String id;
  final String rawType;
  final String title;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final NotificationTargetType targetType;
  final String? targetId;
  final String? actionText;
  final String? eventCode;
  final String? appendixId;

  const NotificationItemModel({
    required this.id,
    required this.rawType,
    required this.title,
    required this.content,
    required this.sentAt,
    required this.isRead,
    this.targetType = NotificationTargetType.none,
    this.targetId,
    this.actionText,
    this.eventCode,
    this.appendixId,
  });

  NotificationItemModel copyWith({
    String? id,
    String? rawType,
    String? title,
    String? content,
    DateTime? sentAt,
    bool? isRead,
    NotificationTargetType? targetType,
    String? targetId,
    String? actionText,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      rawType: rawType ?? this.rawType,
      title: title ?? this.title,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      actionText: actionText ?? this.actionText,
      eventCode: eventCode,
      appendixId: appendixId,
    );
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      final rawTime = json['thoiGianGui'] ?? json['sentAt'] ?? '';
      parsedTime = DateTime.parse(rawTime.toString()).toLocal();
    } catch (_) {
      parsedTime = DateTime.now();
    }

    final rawType =
        (json['loai'] ?? json['type'] ?? '').toString().toUpperCase();
    final isRead = json['daDoc'] == true || json['isRead'] == true;

    // Check if optional target navigation is provided
    NotificationTargetType targetType = NotificationTargetType.none;
    String? targetId =
        json['targetId']?.toString() ?? json['maDich']?.toString();
    String? actionText = json['actionText']?.toString();

    final rawTargetType = json['targetType']?.toString().toLowerCase();
    if (rawTargetType == 'contract' || rawTargetType == 'hop_dong') {
      targetType = NotificationTargetType.contract;
      actionText ??= 'Xem chi tiết';
    }

    return NotificationItemModel(
      id: (json['maThongBao'] ?? json['id'] ?? '').toString(),
      rawType: rawType,
      title: (json['tieuDe'] ?? json['title'] ?? '').toString(),
      content: (json['noiDung'] ?? json['content'] ?? '').toString(),
      sentAt: parsedTime,
      isRead: isRead,
      targetType: targetType,
      targetId: targetId,
      actionText: actionText,
      eventCode: json['eventCode'] as String?,
      appendixId: json['maPhuLuc'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maThongBao': id,
      'loai': rawType,
      'tieuDe': title,
      'noiDung': content,
      'thoiGianGui': sentAt.toIso8601String(),
      'daDoc': isRead,
      if (targetType != NotificationTargetType.none)
        'targetType': targetType.name,
      if (targetId != null) 'targetId': targetId,
      if (actionText != null) 'actionText': actionText,
      if (eventCode != null) 'eventCode': eventCode,
      if (appendixId != null) 'maPhuLuc': appendixId,
    };
  }

  bool get isExtension =>
      eventCode?.startsWith('EXTENSION_') == true ||
      rawType.toUpperCase() == 'GIA_HAN' ||
      rawType.toUpperCase() == 'EXTENSION';

  String get displayTitle => switch (eventCode) {
    'EXTENSION_CHO_KY' => 'Gia hạn được duyệt – Chờ ký phụ lục',
    'EXTENSION_TU_CHOI' => 'Gia hạn bị từ chối',
    _ => title,
  };

  /// The current API targets a contract, not a specific appendix. Never guess
  /// from status alone when historical requests could match the same event.
  String? resolveAppendixId(List<Map<String, dynamic>> rows) {
    if (!isExtension) return null;
    if (appendixId != null) {
      return rows.any(
            (r) =>
                r['maPhuLuc'] == appendixId &&
                (r['maHopDong'] == null || r['maHopDong'] == targetId),
          )
          ? appendixId
          : null;
    }
    if (rows.length != 1) return null;
    final row = rows.single;
    if (row['maHopDong'] != null && row['maHopDong'] != targetId) return null;
    final id = row['maPhuLuc']?.toString();
    return id?.isNotEmpty == true ? id : null;
  }

  /// Categorizes this notification into business filters
  bool matchesCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.all:
        return true;
      case NotificationCategory.unread:
        return !isRead;
      case NotificationCategory.contract:
        return isContractRelated;
      case NotificationCategory.payment:
        return isPaymentRelated;
    }
  }

  /// Contract-related types: HOP_DONG, BAN_GIAO, GIA_HAN
  bool get isContractRelated {
    final t = rawType.toUpperCase();
    return t == 'HOP_DONG' ||
        t == 'CONTRACT' ||
        t == 'BAN_GIAO' ||
        t == 'HANDOVER' ||
        t == 'GIA_HAN' ||
        t == 'EXTENSION';
  }

  /// Payment-related types: THANH_TOAN, HOAN_TIEN
  bool get isPaymentRelated {
    final t = rawType.toUpperCase();
    return t == 'THANH_TOAN' ||
        t == 'PAYMENT' ||
        t == 'HOAN_TIEN' ||
        t == 'REFUND';
  }

  /// Reservation: GIU_CHO (belongs to all/unread, not in contract/payment)
  bool get isReservationRelated {
    final t = rawType.toUpperCase();
    return t == 'GIU_CHO' || t == 'RESERVATION';
  }
}
