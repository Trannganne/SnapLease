import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/notification_item_model.dart';

class NotificationPageResult {
  final int page;
  final int pageSize;
  final int totalCount;
  final List<NotificationItemModel> items;

  const NotificationPageResult({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.items,
  });
}

abstract class NotificationRepository {
  Future<NotificationItemModel> getNotification(String id);
  Future<NotificationPageResult> getNotifications({
    bool? daDoc,
    NotificationCategory category = NotificationCategory.all,
    int page = 1,
    int pageSize = 20,
  });

  Future<int> getTotalUnreadCount();

  Future<void> markAsRead(String id);
}

class DioNotificationRepository implements NotificationRepository {
  final Dio _dio;

  DioNotificationRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;
  @override
  Future<NotificationItemModel> getNotification(String id) async =>
      NotificationItemModel.fromJson(
        Map<String, dynamic>.from(
          (await _dio.get('/api/thong-bao/$id')).data as Map,
        ),
      );

  @override
  Future<NotificationPageResult> getNotifications({
    bool? daDoc,
    NotificationCategory category = NotificationCategory.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'trang': page,
      'kichThuocTrang': pageSize,
    };
    if (daDoc != null) {
      queryParams['daDoc'] = daDoc;
    }
    if (category == NotificationCategory.contract) {
      queryParams['nhom'] = 'HOP_DONG';
    }
    if (category == NotificationCategory.payment) {
      queryParams['nhom'] = 'THANH_TOAN';
    }

    final response = await _dio.get(
      '/api/thong-bao',
      queryParameters: queryParams,
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final itemsRaw = data['duLieu'];
      final List<NotificationItemModel> items = [];
      if (itemsRaw is List) {
        for (var item in itemsRaw) {
          if (item is Map<String, dynamic>) {
            items.add(NotificationItemModel.fromJson(item));
          }
        }
      }

      final page = (data['trang'] as num?)?.toInt() ?? 1;
      final pageSize = (data['kichThuocTrang'] as num?)?.toInt() ?? 20;
      final total = (data['tongSo'] as num?)?.toInt() ?? items.length;

      return NotificationPageResult(
        page: page,
        pageSize: pageSize,
        totalCount: total,
        items: items,
      );
    }

    return NotificationPageResult(
      page: page,
      pageSize: pageSize,
      totalCount: 0,
      items: const [],
    );
  }

  @override
  Future<int> getTotalUnreadCount() async {
    try {
      final response = await _dio.get(
        '/api/thong-bao',
        queryParameters: {'daDoc': false, 'trang': 1, 'kichThuocTrang': 1},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return (data['tongSo'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      rethrow;
    }
    throw const FormatException('API thiếu tổng thông báo chưa đọc.');
  }

  @override
  Future<void> markAsRead(String id) async {
    await _dio.put('/api/thong-bao/$id/da-doc');
  }
}

/// Mock / Fixture repository for widget testing and previewing the 5 visual states
class MockNotificationRepository implements NotificationRepository {
  @override
  Future<NotificationItemModel> getNotification(String id) async =>
      _items.singleWhere((x) => x.id == id);
  List<NotificationItemModel> _items;

  MockNotificationRepository({List<NotificationItemModel>? initialItems})
    : _items = initialItems ?? NotificationDemoData.sampleNotifications;

  void setItems(List<NotificationItemModel> items) {
    _items = List.from(items);
  }

  @override
  Future<NotificationPageResult> getNotifications({
    bool? daDoc,
    NotificationCategory category = NotificationCategory.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    var filtered = _items.where((i) => i.matchesCategory(category)).toList();
    if (daDoc != null) {
      filtered = filtered.where((e) => e.isRead == daDoc).toList();
    }

    // Sort newest first
    filtered.sort((a, b) => b.sentAt.compareTo(a.sentAt));

    final total = filtered.length;
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= total) {
      return NotificationPageResult(
        page: page,
        pageSize: pageSize,
        totalCount: total,
        items: const [],
      );
    }
    final endIndex = (startIndex + pageSize).clamp(0, total);
    final pageItems = filtered.sublist(startIndex, endIndex);

    return NotificationPageResult(
      page: page,
      pageSize: pageSize,
      totalCount: total,
      items: pageItems,
    );
  }

  @override
  Future<int> getTotalUnreadCount() async {
    return _items.where((e) => !e.isRead).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final index = _items.indexWhere((e) => e.id == id);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isRead: true);
    }
  }
}

class NotificationDemoData {
  static List<NotificationItemModel> get sampleNotifications {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(hours: 6));
    return [
      NotificationItemModel(
        id: 'TB-DEMO-001',
        rawType: 'GIU_CHO',
        title: 'Giữ chỗ sắp hết hạn',
        content:
            'Thiết bị Sony Alpha A7 IV tại chi nhánh Q1 của bạn sẽ hết hạn giữ chỗ trong 15 phút. Vui lòng xác nhận.',
        sentAt: today.add(const Duration(hours: 2)),
        isRead: false,
        targetType: NotificationTargetType.none,
      ),
      NotificationItemModel(
        id: 'TB-DEMO-002',
        rawType: 'HOP_DONG',
        title: 'Hợp đồng đã ký thành công',
        content:
            'Hợp đồng #HD001 đã hoàn tất thủ tục ký kết trực tuyến. Vui lòng kiểm tra thông tin thanh toán cọc.',
        sentAt: today.add(const Duration(hours: 1)),
        isRead: false,
        targetType: NotificationTargetType.contract,
        targetId: 'HD001',
        actionText: 'Xem chi tiết',
      ),
      NotificationItemModel(
        id: 'TB-DEMO-003',
        rawType: 'THANH_TOAN',
        title: 'Thanh toán cọc thành công',
        content:
            'Đã nhận thanh toán cọc 2.000.000đ cho hợp đồng #HD001 qua VNPAY.',
        sentAt: today,
        isRead: true,
      ),
      NotificationItemModel(
        id: 'TB-DEMO-004',
        rawType: 'BAN_GIAO',
        title: 'Thiết bị sẵn sàng bàn giao',
        content:
            'Thiết bị máy ảnh Canon EOS R6 Mark II và Lens 24-70mm đã được chuẩn bị sẵn sàng tại cửa hàng.',
        sentAt: yesterday.subtract(const Duration(hours: 2)),
        isRead: false,
        targetType: NotificationTargetType.contract,
        targetId: 'HD002',
        actionText: 'Xem chi tiết',
      ),
      NotificationItemModel(
        id: 'TB-DEMO-005',
        rawType: 'GIA_HAN',
        title: 'Gia hạn được chấp thuận',
        content:
            'Yêu cầu gia hạn hợp đồng #HD003 thêm 2 ngày đã được cửa hàng xác nhận.',
        sentAt: yesterday.subtract(const Duration(hours: 5)),
        isRead: true,
        targetType: NotificationTargetType.contract,
        targetId: 'HD003',
        actionText: 'Xem chi tiết',
      ),
      NotificationItemModel(
        id: 'TB-DEMO-006',
        rawType: 'HOAN_TIEN',
        title: 'Cọc đã hoàn trả',
        content:
            'Khoản tiền hoàn cọc 1.500.000đ cho hợp đồng #HD004 đã được chuyển hoàn về tài khoản của bạn.',
        sentAt: today.subtract(const Duration(days: 3)),
        isRead: true,
      ),
      NotificationItemModel(
        id: 'TB-DEMO-007',
        rawType: 'XAC_MINH_GIAY_TO',
        title: 'Kết quả xác minh giấy tờ',
        content:
            'Hồ sơ CCCD của bạn đã được đối chiếu và xác minh danh tính thành công trên hệ thống SNAPLEASE.',
        sentAt: today.subtract(const Duration(days: 5)),
        isRead: true,
      ),
    ];
  }
}
