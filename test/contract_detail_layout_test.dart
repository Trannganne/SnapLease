import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/data/repositories/contract_document_repository.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/features/contract/presentation/tracking/contract_tracking_page.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';

// Test-only API response: booked quantities are independent of assigned serials.
Map<String, dynamic> _response({String status = 'DANG_THUE'}) => {
  'maHopDong': 'HD-LAYOUT-TEST',
  'ngayTaoHopDong': '2026-10-01T10:00:00',
  'thoiGianBanGiao': '2026-10-10T09:00:00',
  'thoiGianTraDuKien': '2026-10-12T09:00:00',
  'trangThai': status,
  'tongTien': 1000000,
  'tongTienCoc': 3000000,
  'thanhToan': [],
  'phuLuc': [],
  'khachThue': {
    'hoTen': 'Nguyễn Khách Thuê Có Họ Và Tên Rất Dài',
    'cccd': '012345678901',
    'soDienThoai': '0901234567',
  },
  'chiNhanh': {
    'tenCuaHang': 'Chi nhánh kiểm thử có tên dài trên màn hình nhỏ',
    'diaChi':
        '123 Đường Có Tên Rất Dài, Phường Kiểm Thử, Thành phố Hồ Chí Minh',
    'soDienThoai': '02812345678',
  },
  'datTheoDongMay': [
    {'maDongMay': 'DM1', 'tenDongMay': 'Sony Alpha', 'soLuong': 2},
    {'maDongMay': 'DM2', 'tenDongMay': 'Canon EOS', 'soLuong': 1},
  ],
  'chiTiet': [
    {
      'maChiTietHopDong': 'CT1',
      'maThietBi': 'TB1',
      'maDongMay': 'DM1',
      'soSerial': 'SERIAL-SONY-ONE',
      'tinhTrangLucGiao': 'Hoạt động tốt, đầy đủ thông tin kiểm tra thiết bị',
      'ngayGiaoThucTe': '2026-10-10T09:15:00',
      'anhBienBan': [],
    },
  ],
};

class _Repository extends ContractRepository {
  _Repository(this.response);
  Map<String, dynamic> response;
  final requestedIds = <String>[];

  @override
  Future<Map<String, dynamic>> getContractById(String id) async {
    requestedIds.add(id);
    return response;
  }

  @override
  Future<void> cancelContract(String id) => throw UnimplementedError();

  @override
  Future<List<int>> getHandoverImage(String url) => throw UnimplementedError();
}

Widget _app(_Repository repository, {double scale = 1, double bottom = 0}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              padding: EdgeInsets.only(bottom: bottom),
            ),
            child: child!,
          ),
      home: ContractPage(contractId: 'HD-LAYOUT-TEST', repository: repository),
    );

void main() {
  testWidgets(
    'details opens the same contract in tracking, Android Back reloads details',
    (tester) async {
      final repository = _Repository(_response());
      final router = GoRouter(
        initialLocation: '/contract/HD-LAYOUT-TEST',
        routes: [
          GoRoute(
            path: '/contract/tracking',
            builder:
                (context, state) => ContractTrackingPage(
                  contract: state.extra! as ContractModel,
                  repository: repository,
                ),
          ),
          GoRoute(
            path: '/contract/:id',
            builder:
                (context, state) => ContractPage(
                  contractId: state.pathParameters['id']!,
                  repository: repository,
                ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contract-open-tracking')));
      await tester.pumpAndSettle();
      expect(find.byType(ContractTrackingPage), findsOneWidget);
      expect(find.text('Mã HĐ: HD-LAYOUT-TEST'), findsOneWidget);
      expect(repository.requestedIds, ['HD-LAYOUT-TEST', 'HD-LAYOUT-TEST']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ContractTrackingPage), findsNothing);
      expect(find.byKey(const ValueKey('contract-summary')), findsOneWidget);
      expect(repository.requestedIds.length, 3);
      await tester.tap(find.byKey(const ValueKey('contract-open-tracking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(find.byType(ContractTrackingPage), findsNothing);
      expect(repository.requestedIds.length, 5);
      expect(tester.takeException(), isNull);
    },
  );

  for (final status in ['CHO_KY', 'DA_KY', 'CHO_BAN_GIAO', 'DANG_THUE']) {
    testWidgets('$status fits 320px with large text and Android safe area', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository(_response(status: status));
      if (status == 'DA_KY') {
        repository.response['thanhToan'] = [
          {
            'maThanhToan': 'TT-PENDING',
            'loaiThanhToan': 'TIEN_COC',
            'trangThai': 'CHO_THANH_TOAN',
            'soTien': 3000000,
            'phuongThuc': 'TIEN_MAT',
          },
        ];
      }
      await tester.pumpWidget(_app(repository, scale: 2, bottom: 34));
      await tester.pumpAndSettle();
      expect(find.text('Sony Alpha'), findsOneWidget);
      expect(find.textContaining('Đã gán 1/2'), findsOneWidget);
      expect(find.textContaining('Đã gán 0/1'), findsOneWidget);
      expect(find.text('Chưa gán thiết bị'), findsOneWidget);
      expect(find.text('Serial: SERIAL-SONY-ONE'), findsOneWidget);
      expect(find.text('Giao thực tế: 09:15 • 10/10/2026'), findsOneWidget);
      expect(find.textContaining('Đã nhận thiết bị'), findsNothing);
      final scrollable =
          find
              .descendant(
                of: find.byType(SingleChildScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      // Exercise layout and hit testing through the entire long document.
      for (
        double offset = 0;
        offset < position.maxScrollExtent;
        offset += 200
      ) {
        position.jumpTo(offset);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract-download-pdf')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('contract-download-pdf')).hitTestable(),
        findsOneWidget,
      );
      if (status == 'CHO_KY' || status == 'DA_KY') {
        final button = find.byKey(const ValueKey('contract-primary-action'));
        expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(640 - 34));
        expect(button.hitTestable(), findsOneWidget);
        final action = tester.widget<ElevatedButton>(button);
        expect(action.onPressed == null, status == 'CHO_KY');
      }
      if (status == 'DA_KY') {
        expect(find.textContaining('Cọc chờ xác nhận:'), findsOneWidget);
        expect(find.text('Tiền cọc đã thanh toán'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'preview receives the full model and PDF button shares stored PDF bytes',
    (tester) async {
      final repository = _Repository(_response());
      final pdfBytes = ascii.encode('%PDF-1.7\nstored-test-document');
      final documentDio = Dio();
      documentDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api/hop-dong/HD-LAYOUT-TEST/tep-pdf');
            handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                data: pdfBytes,
                statusCode: 200,
              ),
            );
          },
        ),
      );
      addTearDown(documentDio.close);
      final documents = ContractDocumentRepository(dio: documentDio);
      ContractModel? preview;
      final router = GoRouter(
        initialLocation: '/contract/HD-LAYOUT-TEST',
        routes: [
          GoRoute(
            path: '/contract/preview',
            builder: (context, state) {
              preview = state.extra! as ContractModel;
              return const Scaffold(body: Text('Preview destination'));
            },
          ),
          GoRoute(
            path: '/contract/:id',
            builder:
                (context, state) => ContractPage(
                  contractId: state.pathParameters['id']!,
                  repository: repository,
                  documentRepository: documents,
                ),
          ),
        ],
      );
      addTearDown(router.dispose);
      const channel = MethodChannel('net.nfet.printing');
      final shared = Completer<Map<dynamic, dynamic>>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'sharePdf') {
          shared.complete(call.arguments as Map<dynamic, dynamic>);
          return 1;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract-preview')),
      );
      await tester.tap(find.byKey(const ValueKey('contract-preview')));
      await tester.pumpAndSettle();
      expect(preview!.contractId, 'HD-LAYOUT-TEST');
      expect(preview!.bookedDevices.length, 2);
      expect(preview!.assignedDevices.single.serial, 'SERIAL-SONY-ONE');
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract-download-pdf')),
      );
      await tester.tap(find.byKey(const ValueKey('contract-download-pdf')));
      await tester.pumpAndSettle();
      expect(shared.isCompleted, isTrue);
      final arguments = await shared.future;
      expect(arguments['name'], 'HD-LAYOUT-TEST.pdf');
      expect(
        ascii.decode((arguments['doc'] as List<int>).take(5).toList()),
        '%PDF-',
      );
      expect(arguments['doc'], pdfBytes);
      expect(tester.takeException(), isNull);
    },
  );
}
