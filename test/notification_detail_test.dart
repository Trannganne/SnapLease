import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/features/notification/data/notification_detail_fixtures.dart';
import 'package:rentcam/features/notification/data/repositories/notification_repository.dart';
import 'package:rentcam/features/notification/presentation/notification_detail_page.dart';
import 'package:rentcam/features/notification/presentation/notification_preview_page.dart';
import 'package:rentcam/features/notification/presentation/widgets/notification_detail_content_card.dart';
import 'package:rentcam/features/notification/presentation/widgets/notification_return_warning_card.dart';
import 'package:rentcam/features/notification/presentation/widgets/notification_related_contract_card.dart';
import 'package:rentcam/core/widgets/primary_button.dart';

void main() {
  group('Notification Detail Screen Tests (4 Variants)', () {
    testWidgets(
      'Variant A: Displays "Hợp đồng đang chờ ký" with amber styling & CTA "Ký hợp đồng"',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantA;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Summary
        expect(find.text('Hợp đồng đang chờ ký'), findsOneWidget);
        expect(find.text('Mới'), findsOneWidget);

        // Check Content: No "NỘI DUNG THÔNG BÁO" label or decoration bar
        expect(find.byType(NotificationDetailContentCard), findsOneWidget);
        expect(find.text('NỘI DUNG THÔNG BÁO'), findsNothing);

        // Check Contract Card
        expect(find.byType(NotificationRelatedContractCard), findsOneWidget);
        expect(find.text('HD000125'), findsOneWidget);
        expect(find.text('• Chờ ký'), findsOneWidget);
        expect(find.text('Sony Alpha A7 IV Body'), findsOneWidget);
        expect(find.text('Gói bảo hiểm SnapCare+ • 3 ngày'), findsOneWidget);
        expect(find.text('10:30 (còn 15 phút)'), findsOneWidget);

        // Check Fixed CTA
        expect(
          find.widgetWithText(PrimaryButton, 'Ký hợp đồng'),
          findsOneWidget,
        );
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.widgetWithText(PrimaryButton, 'Ký hợp đồng'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.enabled, isTrue);
      },
    );

    testWidgets(
      'Variant A Edge Case: Expired signing deadline disables CTA with expired message',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantAExpired;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng đã hết hạn ký'), findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.widgetWithText(PrimaryButton, 'Hợp đồng đã hết hạn ký'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(button.enabled, isFalse);
      },
    );

    testWidgets(
      'Variant B: Displays "Hợp đồng đã được ký thành công" with "Đã xác thực" and multiple devices',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantB;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Summary
        expect(find.text('Hợp đồng đã được ký thành công'), findsOneWidget);
        expect(find.text('Đã xác thực'), findsOneWidget);

        // Check Contract Card & Combo details
        expect(find.text('HD000123'), findsOneWidget);
        expect(find.text('• Đã ký'), findsOneWidget);
        expect(find.text('Sony A7 IV + Lens 24-70mm GM II'), findsOneWidget);
        expect(find.text('+1 phụ kiện'), findsOneWidget);
        expect(find.text('Đã thanh toán (2.000.000đ)'), findsOneWidget);

        // Check Fixed CTA
        expect(
          find.widgetWithText(PrimaryButton, 'Xem hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Variant C: Displays "Hợp đồng đã bắt đầu" with "Theo dõi hợp đồng" CTA',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantC;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng đã bắt đầu'), findsOneWidget);
        expect(find.text('HD000120'), findsOneWidget);
        expect(find.text('• Đang thuê'), findsOneWidget);
        expect(find.text('Canon EOS R5 Mirrorless...'), findsOneWidget);
        expect(find.text('Bảo hiểm toàn diện kích hoạt'), findsOneWidget);
        expect(find.text('Mới 98% (Đã ký biên bản bàn giao)'), findsOneWidget);

        expect(
          find.widgetWithText(PrimaryButton, 'Theo dõi hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Variant D: Displays "Hợp đồng sắp đến hạn trả" with return warning card',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantD;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng sắp đến hạn trả'), findsOneWidget);
        expect(find.text('Quan trọng'), findsOneWidget);

        // Check Return Warning Card
        expect(find.byType(NotificationReturnWarningCard), findsOneWidget);
        expect(find.text('THỜI HẠN HOÀN TRẢ'), findsOneWidget);

        // Check Contract Card
        expect(find.text('HD000118'), findsOneWidget);
        expect(
          find.widgetWithText(PrimaryButton, 'Xem hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Variant D Edge Case: Overdue displays "Đã quá hạn trả"', (
      WidgetTester tester,
    ) async {
      final fixture = NotificationDetailFixtures.variantDOverdue;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationDetailPage(
            notificationId: fixture.notification.id,
            initialItem: fixture.notification,
            notificationRepository: MockNotificationRepository(),
            isDemo: true,
            demoContract: fixture.contract,
            demoVariant: fixture.variantCode,
            demoMetadata: fixture.metadata,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã quá hạn trả'), findsOneWidget);
      expect(find.text('• Quá hạn'), findsOneWidget);
    });

    testWidgets(
      'Edge Case: Notification without linked contract does NOT render fake contract',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.noContractFixture;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: null,
              demoVariant: fixture.variantCode,
              demoMetadata: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Hồ sơ xác minh danh tính đã được phê duyệt'),
          findsOneWidget,
        );
        expect(find.byType(NotificationDetailContentCard), findsOneWidget);
        expect(find.byType(NotificationRelatedContractCard), findsNothing);
        // No redundant "Đã xem" button when there is no contract target
        expect(find.byType(PrimaryButton), findsNothing);
      },
    );

    testWidgets(
      'Missing item displays error state with back button and does not crash',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NotificationDetailPage(
              notificationId: 'UNKNOWN-ID',
              initialItem: null,
              isDemo: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Không thể tải chi tiết thông báo. Dữ liệu thông báo không tồn tại.',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(PrimaryButton, 'Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'Demo CTA tap shows snackbar "Bản xem trước — chưa thực hiện thao tác"',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantA;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NotificationDetailPage(
                notificationId: fixture.notification.id,
                initialItem: fixture.notification,
                notificationRepository: MockNotificationRepository(),
                isDemo: true,
                demoContract: fixture.contract,
                demoVariant: fixture.variantCode,
                demoMetadata: fixture.metadata,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(PrimaryButton, 'Ký hợp đồng'));
        await tester.pump();

        expect(
          find.text('Bản xem trước — chưa thực hiện thao tác'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Responsive & Text scale factor 1.5 does not cause overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fixture = NotificationDetailFixtures.variantA;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No overflow exceptions thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Completed Variant: Displays "Hợp đồng đã hoàn thành" with "Hoàn thành" badge, contract info card & CTA "Xem chi tiết hợp đồng"',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.variantCompleted;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Summary
        expect(find.text('Hợp đồng đã hoàn thành'), findsOneWidget);
        expect(find.text('Hoàn thành'), findsOneWidget);

        // Check Contract Card Header
        expect(find.byType(NotificationRelatedContractCard), findsOneWidget);
        expect(find.text('Thông tin hợp đồng'), findsOneWidget);
        expect(find.text('#HD001'), findsOneWidget);

        // Check Device Info & Serial
        expect(find.text('Sony Alpha A7 IV Body'), findsOneWidget);
        expect(find.text('Số lượng: 1 • S/N: SN-A7M4-8891'), findsOneWidget);

        // Check Metadata Rows
        expect(find.text('Trạng thái hợp đồng'), findsOneWidget);
        expect(find.text('• Hoàn tất'), findsOneWidget);
        expect(find.text('Thời gian thuê'), findsOneWidget);
        expect(find.text('01/08/2026 - 07/08/2026 (6 ngày)'), findsOneWidget);
        expect(find.text('Ngày nhận lại thực tế'), findsOneWidget);
        expect(find.text('07/08/2026 • 18:20'), findsOneWidget);
        expect(find.text('Chi nhánh'), findsOneWidget);
        expect(find.text('SNAPLEASE Hub Quận 1'), findsOneWidget);

        // Check Fixed CTA
        expect(
          find.widgetWithText(PrimaryButton, 'Xem chi tiết hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Completed Variant (Real DTO without target): Displays real text neatly without fake card and without redundant "Đã xem" button',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.completedNoTarget;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Summary & Real Text
        expect(find.text('Hợp đồng đã hoàn thành'), findsOneWidget);
        expect(find.text('Hoàn thành'), findsOneWidget);
        expect(find.text('Hợp đồng HD001 đã hoàn thành'), findsOneWidget);

        // No fake contract card
        expect(find.byType(NotificationRelatedContractCard), findsNothing);

        // No redundant "Đã xem" button
        expect(find.widgetWithText(PrimaryButton, 'Đã xem'), findsNothing);
        expect(
          find.widgetWithText(PrimaryButton, 'Xem chi tiết hợp đồng'),
          findsNothing,
        );
      },
    );

    testWidgets('Completed Variant: Contract loading state displays skeleton', (
      WidgetTester tester,
    ) async {
      final fixture = NotificationDetailFixtures.completedLoading;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationDetailPage(
            notificationId: fixture.notification.id,
            initialItem: fixture.notification,
            notificationRepository: MockNotificationRepository(),
            isDemo: true,
            demoContract: fixture.contract,
            demoVariant: fixture.variantCode,
            demoMetadata: fixture.metadata,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hợp đồng đã hoàn thành'), findsOneWidget);
      expect(find.byType(NotificationRelatedContractCard), findsNothing);
    });

    testWidgets(
      'Completed Variant: Contract load error displays retry option without losing notification content',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.completedError;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng đã hoàn thành'), findsOneWidget);
        expect(
          find.text('Không thể tải dữ liệu hợp đồng liên kết'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
      },
    );

    testWidgets(
      'Completed Variant: Contract not found / unauthorized does not leak technical details',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.completedNotFound;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng đã hoàn thành'), findsOneWidget);
        expect(
          find.text(
            'Thông tin hợp đồng liên quan hiện không khả dụng hoặc bạn không có quyền truy cập.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('thiếu targetId'), findsNothing);
      },
    );

    testWidgets(
      'Completed Variant: Multi-device with long names & serials renders properly',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.completedMultiDevices;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Sony FX3 Full-Frame Cinema Line Camera Body'),
          findsOneWidget,
        );
        expect(find.text('Số lượng: 1 • S/N: SN-FX3-9921'), findsOneWidget);
        expect(
          find.text('Ống kính Sony FE 24-70mm F2.8 GM II Zoom Lens Nano AR II'),
          findsOneWidget,
        );
        expect(find.text('Số lượng: 1 • S/N: SN-GM2-4412'), findsOneWidget);
      },
    );

    testWidgets(
      'Edge Case: Historical event vs Current contract status mismatch',
      (WidgetTester tester) async {
        final fixture = NotificationDetailFixtures.completedStatusMismatch;

        await tester.pumpWidget(
          MaterialApp(
            home: NotificationDetailPage(
              notificationId: fixture.notification.id,
              initialItem: fixture.notification,
              notificationRepository: MockNotificationRepository(),
              isDemo: true,
              demoContract: fixture.contract,
              demoVariant: fixture.variantCode,
              demoMetadata: fixture.metadata,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Notification summary preserves historical event title
        expect(find.text('Hợp đồng đã được ký thành công'), findsOneWidget);

        // Contract card displays updated contract status • Hoàn tất
        expect(find.text('• Hoàn tất'), findsOneWidget);
        expect(
          find.widgetWithText(PrimaryButton, 'Xem chi tiết hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'NotificationPreviewPage renders choice chips and switches fixtures cleanly',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: NotificationPreviewPage()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Preview Chi tiết thông báo'), findsOneWidget);
        expect(
          find.text('Hoàn tất: Đầy đủ liên kết & dữ liệu'),
          findsOneWidget,
        );
        expect(
          find.text('Hoàn tất: Dữ liệu thật thiếu liên kết'),
          findsOneWidget,
        );

        // Tap 'Hoàn tất: Dữ liệu thật thiếu liên kết'
        await tester.tap(find.text('Hoàn tất: Dữ liệu thật thiếu liên kết'));
        await tester.pumpAndSettle();

        expect(find.text('Hợp đồng HD001 đã hoàn thành'), findsOneWidget);
        expect(find.byType(NotificationRelatedContractCard), findsNothing);

        // Tap 'Hoàn tất: Đầy đủ liên kết & dữ liệu'
        await tester.tap(find.text('Hoàn tất: Đầy đủ liên kết & dữ liệu'));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationRelatedContractCard), findsOneWidget);
        expect(find.text('#HD001'), findsOneWidget);
      },
    );
  });
}
