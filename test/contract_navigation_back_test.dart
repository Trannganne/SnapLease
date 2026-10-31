import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcam/app/router/app_router.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/features/contract/presentation/contract_preview_page.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_page.dart';
import 'package:rentcam/features/contract/presentation/tracking/contract_tracking_page.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'package:rentcam/features/main/presentation/main_layout.dart';
import 'package:rentcam/features/payment/presentation/payment_page.dart';
import 'package:rentcam/features/payment/presentation/payment_result_page.dart';
import 'package:rentcam/features/payment/presentation/payment_success_page.dart';

class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GoRouterState makeState(
  GoRouter router,
  String path, {
  Object? extra,
  Map<String, String> pathParameters = const {},
}) {
  final cleanPath = path.split('?').first;
  return GoRouterState(
    router.configuration,
    uri: Uri.parse(path),
    matchedLocation: cleanPath,
    fullPath: cleanPath,
    pathParameters: pathParameters,
    extra: extra,
    pageKey: const ValueKey('test'),
  );
}

void main() {
  final sampleContract = ContractModel(
    contractId: 'HD590AA8870118409BBF',
    date: DateTime.now(),
    lessorName: 'SNAPLEASE',
    lessorAddress: 'CN Snaplease',
    lessorPhone: '1900 1234',
    lesseeName: 'Nguyễn Văn A',
    lesseeId: '012345678901',
    lesseePhone: '0901234567',
    deviceName: 'Canon R6',
    deviceModel: 'Canon EOS R6 Mark II',
    quantity: 1,
    pricePerDay: 500000,
    pickupDate: DateTime.now(),
    returnDate: DateTime.now().add(const Duration(days: 2)),
    rentalDays: 2,
    branchName: 'Chi nhánh 1',
    rentalTotal: 1000000,
    deposit: 500000,
    totalAmount: 1500000,
    status: 'DA_KY',
  );

  group('Kiểm thử an toàn type cast trên toàn bộ routes của AppRouter', () {
    late GoRouter router;
    late Map<String, GoRoute> routesByPath;

    setUp(() {
      router = AppRouter.createRouter();
      routesByPath = {
        for (final route in router.configuration.routes)
          if (route is GoRoute) route.path: route,
      };
    });

    test('Route /: Truy cập tab=contracts mở MainLayout với initialIndex = 2', () {
      final homeRoute = routesByPath['/']!;
      final state = makeState(router, '/?tab=contracts');

      final widget = homeRoute.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /contract/tracking: Khi thiếu extra KHÔNG crash Null cast, fallback về MainLayout tab 2', () {
      final route = routesByPath['/contract/tracking']!;
      final state = makeState(router, '/contract/tracking', extra: null);

      // Trước khi sửa: throw type 'Null' is not a subtype of type 'ContractModel'
      // Sau khi sửa: An toàn trả về MainLayout(initialIndex: 2)
      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /contract/tracking: Khi có extra hợp lệ mở đúng ContractTrackingPage', () {
      final route = routesByPath['/contract/tracking']!;
      final state = makeState(router, '/contract/tracking', extra: sampleContract);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<ContractTrackingPage>());
      expect((widget as ContractTrackingPage).contract.contractId, 'HD590AA8870118409BBF');
    });

    test('Route /contract/preview: Khi thiếu extra KHÔNG crash Null cast', () {
      final route = routesByPath['/contract/preview']!;
      final state = makeState(router, '/contract/preview', extra: null);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /contract/preview: Khi có extra hợp lệ mở đúng ContractPreviewPage', () {
      final route = routesByPath['/contract/preview']!;
      final state = makeState(router, '/contract/preview', extra: sampleContract);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<ContractPreviewPage>());
      expect((widget as ContractPreviewPage).contract.contractId, 'HD590AA8870118409BBF');
    });

    test('Route /payment: Khi thiếu extra KHÔNG crash Null cast', () {
      final route = routesByPath['/payment']!;
      final state = makeState(router, '/payment', extra: null);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /payment: Khi có extra hợp lệ mở đúng PaymentPage', () {
      final route = routesByPath['/payment']!;
      final state = makeState(router, '/payment', extra: sampleContract);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<PaymentPage>());
      expect((widget as PaymentPage).contract.contractId, 'HD590AA8870118409BBF');
    });

    test('Route /payment/success: Khi thiếu extra KHÔNG crash Null cast', () {
      final route = routesByPath['/payment/success']!;
      final state = makeState(router, '/payment/success', extra: null);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /payment/success: Khi có extra hợp lệ mở đúng PaymentSuccessPage', () {
      final route = routesByPath['/payment/success']!;
      final state = makeState(router, '/payment/success', extra: sampleContract);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<PaymentSuccessPage>());
      expect((widget as PaymentSuccessPage).contract.contractId, 'HD590AA8870118409BBF');
    });

    test('Route /contract/renewal: Khi thiếu extra KHÔNG crash Null cast', () {
      final route = routesByPath['/contract/renewal']!;
      final state = makeState(router, '/contract/renewal', extra: null);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /contract/renewal: Khi có extra hợp lệ mở đúng ContractRenewalPage', () {
      final route = routesByPath['/contract/renewal']!;
      final state = makeState(router, '/contract/renewal', extra: sampleContract);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<ContractRenewalPage>());
      expect((widget as ContractRenewalPage).contract.contractId, 'HD590AA8870118409BBF');
    });

    test('Route /signature: Khi thiếu extra KHÔNG crash Null cast', () {
      final route = routesByPath['/signature']!;
      final state = makeState(router, '/signature', extra: null);

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<MainLayout>());
      expect((widget as MainLayout).initialIndex, 2);
    });

    test('Route /contract/:id: Mở trực tiếp bằng ID không cần extra, parse đúng ID', () {
      final route = routesByPath['/contract/:id']!;
      final state = makeState(
        router,
        '/contract/HD590AA8870118409BBF',
        pathParameters: {'id': 'HD590AA8870118409BBF'},
        extra: null,
      );

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<ContractPage>());
      expect((widget as ContractPage).contractId, 'HD590AA8870118409BBF');
    });

    test('Route /payment-result: Xử lý query param maThanhToan', () {
      final route = routesByPath['/payment-result']!;
      final state = makeState(router, '/payment-result?maThanhToan=PAY123');

      final widget = route.builder!(MockBuildContext(), state);
      expect(widget, isA<PaymentResultPage>());
      expect((widget as PaymentResultPage).paymentId, 'PAY123');
    });

    test('Custom-scheme callback retains payment ID and ignores claimed status', () async {
      final state = makeState(router,
          'rentalcamera://payment-result?maThanhToan=PAY123&trangThai=THANH_CONG');
      final target = await router.configuration.topRedirect(MockBuildContext(), state);
      expect(Uri.parse(target!).path, '/payment-result');
      final resultState = makeState(router, target);
      final widget = routesByPath['/payment-result']!.builder!(MockBuildContext(), resultState);
      expect((widget as PaymentResultPage).paymentId, 'PAY123');
    });
  });

  group('Kiểm thử xử lý ContractPage với contractId rỗng/sai', () {
    testWidgets('ContractPage với contractId rỗng hiển thị thông báo lỗi, không crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ContractPage(contractId: '   '),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Mã hợp đồng không hợp lệ'), findsOneWidget);
    });
  });
}
