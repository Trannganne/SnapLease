import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/features/notification/bloc/notification_bloc.dart';
import 'package:rentcam/features/notification/bloc/notification_event.dart';
import 'package:rentcam/features/notification/bloc/notification_state.dart';
import 'package:rentcam/features/notification/data/repositories/notification_repository.dart';
import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/notification/presentation/notification_page.dart';

void main() {
  group('NotificationItemModel Tests', () {
    test('parses DTO from backend API correctly', () {
      final json = {
        'maThongBao': 'TB001',
        'maTaiKhoan': 'TK004',
        'loai': 'HOP_DONG',
        'tieuDe': 'Hợp đồng đã hoàn thành',
        'noiDung': 'Hợp đồng #HD001 đã hoàn thành',
        'thoiGianGui': '2026-10-16T10:00:00.000Z',
        'daDoc': false,
      };

      final model = NotificationItemModel.fromJson(json);

      expect(model.id, 'TB001');
      expect(model.rawType, 'HOP_DONG');
      expect(model.title, 'Hợp đồng đã hoàn thành');
      expect(model.content, 'Hợp đồng #HD001 đã hoàn thành');
      expect(model.isRead, false);
      expect(model.isContractRelated, true);
      expect(model.isPaymentRelated, false);
      expect(model.isReservationRelated, false);
    });

    test('categorizes notifications correctly without dropping unknown types', () {
      final now = DateTime.now();
      final reservation = NotificationItemModel(
        id: '1',
        rawType: 'GIU_CHO',
        title: 'Giữ chỗ',
        content: 'Nội dung',
        sentAt: now,
        isRead: false,
      );
      final contract = NotificationItemModel(
        id: '2',
        rawType: 'HOP_DONG',
        title: 'Hợp đồng',
        content: 'Nội dung',
        sentAt: now,
        isRead: true,
      );
      final payment = NotificationItemModel(
        id: '3',
        rawType: 'THANH_TOAN',
        title: 'Thanh toán',
        content: 'Nội dung',
        sentAt: now,
        isRead: false,
      );
      final unknownType = NotificationItemModel(
        id: '4',
        rawType: 'UNKNOWN_CUSTOM_TYPE',
        title: 'Hệ thống',
        content: 'Nội dung lạ',
        sentAt: now,
        isRead: true,
      );

      // Category: all -> all match
      expect(reservation.matchesCategory(NotificationCategory.all), true);
      expect(contract.matchesCategory(NotificationCategory.all), true);
      expect(payment.matchesCategory(NotificationCategory.all), true);
      expect(unknownType.matchesCategory(NotificationCategory.all), true);

      // Category: unread
      expect(reservation.matchesCategory(NotificationCategory.unread), true);
      expect(contract.matchesCategory(NotificationCategory.unread), false);
      expect(payment.matchesCategory(NotificationCategory.unread), true);
      expect(unknownType.matchesCategory(NotificationCategory.unread), false);

      // Category: contract
      expect(reservation.matchesCategory(NotificationCategory.contract), false);
      expect(contract.matchesCategory(NotificationCategory.contract), true);
      expect(payment.matchesCategory(NotificationCategory.contract), false);
      expect(unknownType.matchesCategory(NotificationCategory.contract), false);

      // Category: payment
      expect(reservation.matchesCategory(NotificationCategory.payment), false);
      expect(contract.matchesCategory(NotificationCategory.payment), false);
      expect(payment.matchesCategory(NotificationCategory.payment), true);
      expect(unknownType.matchesCategory(NotificationCategory.payment), false);
    });
  });

  group('NotificationBloc Unit Tests', () {
    late MockNotificationRepository mockRepo;

    setUp(() {
      mockRepo = MockNotificationRepository();
    });

    test('Initial load loads data, calculates total and unread counts', () async {
      final bloc = NotificationBloc(repository: mockRepo);
      bloc.add(const NotificationLoadStarted());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<NotificationState>((s) => s.status == NotificationStatus.loading),
          predicate<NotificationState>((s) =>
              s.status == NotificationStatus.success &&
              s.items.isNotEmpty &&
              s.totalCount == 7 &&
              s.totalUnreadCount == 3),
        ]),
      );
    });

    test('Category change to unread only loads unread items and updates state', () async {
      final bloc = NotificationBloc(repository: mockRepo);
      bloc.add(const NotificationLoadStarted());
      await bloc.stream.firstWhere((s) => s.status == NotificationStatus.success);

      bloc.add(const NotificationCategoryChanged(NotificationCategory.unread));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<NotificationState>((s) =>
              s.selectedCategory == NotificationCategory.unread &&
              s.status == NotificationStatus.loading),
          predicate<NotificationState>((s) =>
              s.selectedCategory == NotificationCategory.unread &&
              s.status == NotificationStatus.success &&
              s.filteredItems.every((item) => !item.isRead)),
        ]),
      );
    });

    test('Mark as read decrements unread count and updates card', () async {
      final bloc = NotificationBloc(repository: mockRepo);
      bloc.add(const NotificationLoadStarted());
      await bloc.stream.firstWhere((s) => s.status == NotificationStatus.success);

      expect(bloc.state.totalUnreadCount, 3);
      final unreadId = bloc.state.items.firstWhere((i) => !i.isRead).id;

      bloc.add(NotificationMarkAsRead(unreadId));

      await expectLater(
        bloc.stream,
        emits(
          predicate<NotificationState>((s) =>
              s.totalUnreadCount == 2 &&
              s.items.firstWhere((i) => i.id == unreadId).isRead == true),
        ),
      );
    });

    test('Date grouping partitions items into today, yesterday, and earlier', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0);
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 6));
      final items = [
        NotificationItemModel(
          id: '1',
          rawType: 'GIU_CHO',
          title: 'Hôm nay 1',
          content: 'Nội dung',
          sentAt: today.add(const Duration(hours: 1)),
          isRead: false,
        ),
        NotificationItemModel(
          id: '2',
          rawType: 'HOP_DONG',
          title: 'Hôm nay 2',
          content: 'Nội dung',
          sentAt: today,
          isRead: true,
        ),
        NotificationItemModel(
          id: '3',
          rawType: 'BAN_GIAO',
          title: 'Hôm qua 1',
          content: 'Nội dung',
          sentAt: yesterday,
          isRead: false,
        ),
        NotificationItemModel(
          id: '4',
          rawType: 'HOAN_TIEN',
          title: 'Trước đó 1',
          content: 'Nội dung',
          sentAt: today.subtract(const Duration(days: 4)),
          isRead: true,
        ),
      ];

      final state = NotificationState(
        status: NotificationStatus.success,
        items: items,
        selectedCategory: NotificationCategory.all,
      );

      final groups = state.dateGroups;
      expect(groups.today.length, 2);
      expect(groups.todayUnread, 1);
      expect(groups.yesterday.length, 1);
      expect(groups.yesterdayUnread, 1);
      expect(groups.earlier.length, 1);
      expect(groups.earlierUnread, 0);
    });
  });

  group('Notification UI & 5 States Widget Tests', () {
    Widget buildTestWidget({
      required NotificationRepository repository,
    }) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D39C4),
            primary: const Color(0xFF1D39C4),
            surface: Colors.white,
          ),
          fontFamily: 'Roboto',
        ),
        home: NotificationPage(repository: repository),
      );
    }

    testWidgets('State 1: Displays full list (Tất cả) with groups, badges, and security card',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Thông báo'), findsOneWidget);

      // Filter chips
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Hợp đồng'), findsOneWidget);

      // Date groups
      expect(find.text('HÔM NAY'), findsOneWidget);
      expect(find.text('HÔM QUA'), findsOneWidget);
      expect(find.text('TRƯỚC ĐÓ'), findsOneWidget);

      // Unread group badge
      expect(find.text('2 mới'), findsOneWidget); // today has 2 unread in sample

      // Cards
      expect(find.text('Giữ chỗ sắp hết hạn'), findsOneWidget);
      expect(find.text('Hợp đồng đã ký thành công'), findsOneWidget);

      // Bottom security card
      expect(find.text('Trung tâm xác thực SNAPLEASE'), findsOneWidget);
      expect(
        find.text('Theo dõi các cập nhật về hợp đồng và thanh toán của bạn.'),
        findsOneWidget,
      );
    });

    testWidgets('State 2: Displays Chưa đọc filter', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap on "Chưa đọc" chip
      await tester.tap(find.text('Chưa đọc'));
      await tester.pumpAndSettle();

      // Should show only unread cards
      expect(find.text('Giữ chỗ sắp hết hạn'), findsOneWidget);
      expect(find.text('Hợp đồng đã ký thành công'), findsOneWidget);
      expect(find.text('Thiết bị sẵn sàng bàn giao'), findsOneWidget);

      // Read items should NOT be present
      expect(find.text('Thanh toán cọc thành công'), findsNothing);
      expect(find.text('Gia hạn được chấp thuận'), findsNothing);
    });

    testWidgets('State 3: Displays Hợp đồng filter', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap on "Hợp đồng" chip
      final hopDongChip = find.text('Hợp đồng');
      await tester.ensureVisible(hopDongChip);
      await tester.tap(hopDongChip);
      await tester.pumpAndSettle();

      // Should show contract, handover, extension
      expect(find.text('Hợp đồng đã ký thành công'), findsOneWidget);
      expect(find.text('Thiết bị sẵn sàng bàn giao'), findsOneWidget);
      expect(find.text('Gia hạn được chấp thuận'), findsOneWidget);

      // Payment and reservation should not be present
      expect(find.text('Giữ chỗ sắp hết hạn'), findsNothing);
      expect(find.text('Thanh toán cọc thành công'), findsNothing);
    });

    testWidgets('State 4: Displays Thanh toán filter', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Scroll horizontal chip row if needed and tap on "Thanh toán" chip
      final thanhToanChip = find.text('Thanh toán');
      await tester.ensureVisible(thanhToanChip);
      await tester.tap(thanhToanChip);
      await tester.pumpAndSettle();

      // Should show deposit payment and refund
      expect(find.text('Thanh toán cọc thành công'), findsOneWidget);
      expect(find.text('Cọc đã hoàn trả'), findsOneWidget);

      // Contract and reservation should not be present
      expect(find.text('Giữ chỗ sắp hết hạn'), findsNothing);
      expect(find.text('Hợp đồng đã ký thành công'), findsNothing);
    });

    testWidgets('State 5: Completely empty state and empty by filter', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyRepo = MockNotificationRepository(initialItems: []);
      await tester.pumpWidget(buildTestWidget(repository: emptyRepo));
      await tester.pumpAndSettle();

      // Empty in "Tất cả"
      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
      expect(find.text('Tải lại'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);

      // Switch to "Chưa đọc"
      await tester.tap(find.text('Chưa đọc'));
      await tester.pumpAndSettle();
      expect(find.text('Không có thông báo chưa đọc'), findsOneWidget);

      // Switch to "Hợp đồng"
      await tester.tap(find.text('Hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo hợp đồng'), findsOneWidget);

      // Switch to "Thanh toán"
      final thanhToanChip = find.text('Thanh toán');
      await tester.ensureVisible(thanhToanChip);
      await tester.tap(thanhToanChip);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông báo thanh toán'), findsOneWidget);
    });

    testWidgets('Tapping unread card marks it as read', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 1600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = MockNotificationRepository();
      await tester.pumpWidget(buildTestWidget(repository: repo));
      await tester.pumpAndSettle();

      // Tap on "Chưa đọc"
      await tester.tap(find.text('Chưa đọc'));
      await tester.pumpAndSettle();

      expect(find.text('Giữ chỗ sắp hết hạn'), findsOneWidget);

      // Tap on card
      await tester.tap(find.text('Giữ chỗ sắp hết hạn'));
      await tester.pumpAndSettle();

      // Since it's marked as read and we are on "Chưa đọc" filter, it disappears
      expect(find.text('Giữ chỗ sắp hết hạn'), findsNothing);
    });
  });
}
