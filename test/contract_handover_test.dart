import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:rentcam/core/network/api_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_detail_cubit.dart';
import 'package:rentcam/features/contract/presentation/tracking/bloc/contract_tracking_state.dart';
import 'package:rentcam/features/contract/presentation/tracking/models/contract_tracking_status.dart';
import 'package:rentcam/features/contract/presentation/widgets/contract_handover_card.dart';
import 'package:rentcam/features/contract/presentation/tracking/contract_tracking_page.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';

Map<String, dynamic> fixture({String status = 'CHO_BAN_GIAO'}) => {
  'maHopDong': 'HDTEST',
  'ngayTaoHopDong': '2026-10-01T10:00:00',
  'thoiGianBanGiao': '2026-10-10T09:00:00',
  'thoiGianTraDuKien': '2026-10-12T09:00:00',
  'ngayKy': '2026-10-02T10:00:00',
  'hinhThucKy': 'DIEN_TU',
  'trangThai': status,
  'tongTien': 1000000,
  'tongTienCoc': 3000000,
  'datTheoDongMay': [
    {
      'maDongMay': 'DM1',
      'tenDongMay': 'Sony',
      'soLuong': 2,
      'donGiaTieuChuan': 100000,
    },
    {
      'maDongMay': 'DM2',
      'tenDongMay': 'Canon',
      'soLuong': 1,
      'donGiaTieuChuan': 200000,
    },
  ],
  'chiTiet': [
    {
      'maChiTietHopDong': 'CT1',
      'maThietBi': 'TB1',
      'maDongMay': 'DM1',
      'soSerial': 'SERIAL1',
    },
    {
      'maChiTietHopDong': 'CT2',
      'maThietBi': 'TB2',
      'maDongMay': 'DM1',
      'soSerial': 'SERIAL2',
      'tinhTrangLucGiao': 'Tốt',
      'ngayGiaoThucTe': '2026-10-10T09:15:00',
      'anhBienBan': [
        {'loai': 'BAN_GIAO', 'duongDanAnh': '/handover.jpg'},
      ],
    },
    {
      'maChiTietHopDong': 'CT3',
      'maThietBi': 'TB3',
      'maDongMay': 'DM2',
      'soSerial': 'SERIAL3',
    },
  ],
};

class QueuedRepository extends ContractRepository {
  final requests = <Completer<Map<String, dynamic>>>[];
  List<int>? imageBytes;
  int imageRequests = 0;
  @override
  Future<Map<String, dynamic>> getContractById(String id) {
    final request = Completer<Map<String, dynamic>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<void> cancelContract(String id) => throw UnimplementedError();
  @override
  Future<List<int>> getHandoverImage(String url) async {
    imageRequests++;
    if (imageBytes != null) return imageBytes!;
    throw Exception('Image unavailable');
  }
}

void main() {
  test(
    'maps every booked model and serial, preserves missing dates and evidence',
    () {
      final model = ContractDetailData.fromJson(fixture(), 'HDTEST').contract;
      expect(model.bookedDevices.length, 2);
      expect(model.quantity, 3);
      expect(model.assignedDevices.map((d) => d.serial), [
        'SERIAL1',
        'SERIAL2',
        'SERIAL3',
      ]);
      expect(model.assignedDevices.first.handedOverAt, isNull);
      expect(model.assignedDevices[1].handoverCondition, 'Tốt');
      expect(model.assignedDevices[1].images.single.url, '/handover.jpg');
      expect(model.copyWith(status: 'DANG_THUE').assignedDevices.length, 3);
      expect(model.returnDate, DateTime(2026, 10, 12, 9));
    },
  );
  test('unassigned contract keeps all booked quantities', () {
    final json = fixture()..['chiTiet'] = [];
    final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
    expect(model.assignedDevices, isEmpty);
    expect(model.bookedDevices.length, 2);
    expect(model.quantity, 3);
  });
  test('missing contract schedule is an error, never fabricated', () {
    final json = fixture()..remove('thoiGianTraDuKien');
    expect(
      () => ContractDetailData.fromJson(json, 'HDTEST'),
      throwsFormatException,
    );
    expect(
      () => ContractDetailData.fromJson(fixture(), 'OTHER'),
      throwsFormatException,
    );
  });
  test('tracking follows Backend even when the due date has passed', () {
    final model =
        ContractDetailData.fromJson(
          fixture(status: 'DANG_THUE'),
          'HDTEST',
        ).contract;
    final state = ContractTrackingState(contract: model);
    expect(state.status, ContractTrackingStatus.renting);
    expect(state.viewData.timelineSteps[2].timestamp, isNull);
    expect(state.viewData.timelineSteps[3].timestamp, isNull);
    expect(
      state.viewData.currentStatusDescription,
      isNot(contains('RentSafe')),
    );
    expect(
      ContractTrackingState(contract: model.copyWith(status: 'DA_HUY')).status,
      ContractTrackingStatus.cancelled,
    );
    expect(
      ContractTrackingState(contract: model.copyWith(status: 'DA_KY')).status,
      ContractTrackingStatus.signed,
    );
  });
  test('latest GET wins when older request finishes afterwards', () async {
    final repository = QueuedRepository();
    final cubit = ContractDetailCubit(
      contractId: 'HDTEST',
      repository: repository,
    );
    final old = cubit.load();
    final latest = cubit.load(force: true);
    repository.requests[1].complete(fixture(status: 'DANG_THUE'));
    await latest;
    repository.requests[0].complete(fixture());
    await old;
    expect(cubit.state.data!.contract.status, 'DANG_THUE');
    await cubit.close();
  });
  test(
    'GET failure retains real data and exposes error; close ignores pending response',
    () async {
      final repository = QueuedRepository();
      final cubit = ContractDetailCubit(
        contractId: 'HDTEST',
        repository: repository,
      );
      final initial = cubit.load();
      repository.requests[0].complete(fixture());
      await initial;
      final failed = cubit.load();
      repository.requests[1].completeError(Exception('Offline'));
      await failed;
      expect(cubit.state.data!.contract.contractId, 'HDTEST');
      expect(cubit.state.error, 'Offline');
      final pending = cubit.load();
      await cubit.close();
      repository.requests[2].complete(fixture(status: 'DANG_THUE'));
      await pending;
      expect(cubit.state.data!.contract.status, 'CHO_BAN_GIAO');
    },
  );
  test(
    'missing/malformed list is a parse error, not an unassigned contract',
    () {
      final missing = fixture()..remove('chiTiet');
      expect(
        () => ContractDetailData.fromJson(missing, 'HDTEST'),
        throwsFormatException,
      );
      final malformed =
          fixture()
            ..['datTheoDongMay'] = [
              {'maDongMay': 'DM1'},
            ];
      expect(
        () => ContractDetailData.fromJson(malformed, 'HDTEST'),
        throwsFormatException,
      );
    },
  );
  test('payment success and pending cash do not change contract status', () {
    final json = fixture(status: 'DA_KY')
      ..['thanhToan'] = [
        {
          'loaiThanhToan': 'TIEN_COC',
          'trangThai': 'THANH_CONG',
          'soTien': 3000000,
        },
        {
          'loaiThanhToan': 'TIEN_THUE',
          'trangThai': 'CHO_THANH_TOAN',
          'phuongThuc': 'TIEN_MAT',
        },
      ];
    final data = ContractDetailData.fromJson(json, 'HDTEST');
    expect(data.contract.status, 'DA_KY');
    expect(data.hasSuccessfulDeposit, isTrue);
    expect(
      ContractTrackingState(contract: data.contract).status,
      ContractTrackingStatus.signed,
    );
  });
  testWidgets(
    'partial assignment groups serials and shows the booked denominator',
    (tester) async {
      final json =
          fixture()
            ..['chiTiet'] = [
              {
                'maChiTietHopDong': 'CT1',
                'maThietBi': 'TB1',
                'maDongMay': 'DM1',
                'soSerial': 'SERIAL1',
              },
            ];
      final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContractHandoverCard(contract: model),
            ),
          ),
        ),
      );
      expect(find.textContaining('Đã gán 1/2'), findsOneWidget);
      expect(find.textContaining('Đã gán 0/1'), findsOneWidget);
      expect(find.text('Serial: SERIAL1'), findsOneWidget);
      expect(find.text('Chưa gán thiết bị'), findsOneWidget);
      expect(find.text('Tình trạng giao: Chưa bàn giao'), findsOneWidget);
      expect(find.text('Giao thực tế: Chưa bàn giao'), findsOneWidget);
    },
  );
  testWidgets(
    'renting with missing delivery fields reports missing information honestly',
    (tester) async {
      final json = fixture(status: 'DANG_THUE');
      json['chiTiet'] = (json['chiTiet'] as List).map((row) =>
        Map<String, dynamic>.from(row as Map)..['anhBienBan'] = []).toList();
      final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContractHandoverCard(contract: model),
            ),
          ),
        ),
      );
      expect(
        find.text('Tình trạng giao: Chưa có thông tin tình trạng giao'),
        findsNWidgets(2),
      );
      expect(
        find.text('Giao thực tế: Chưa có thông tin ngày giao thực tế'),
        findsNWidgets(2),
      );
      expect(find.textContaining('Chưa bàn giao'), findsNothing);
    },
  );
  testWidgets('bad handover image is isolated from the serial list', (
    tester,
  ) async {
    final model = ContractDetailData.fromJson(fixture(), 'HDTEST').contract;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContractHandoverCard(
              contract: model,
              repository: QueuedRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tải được ảnh'), findsOneWidget);
    expect(find.text('Serial: SERIAL1'), findsOneWidget);
    expect(find.text('Serial: SERIAL3'), findsOneWidget);
  });
  testWidgets('thumbnail opens a zoomable dialog without downloading twice', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = Colors.blue);
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return bytes!.buffer.asUint8List();
    });
    final repository = QueuedRepository()..imageBytes = bytes;
    final model = ContractDetailData.fromJson(fixture(), 'HDTEST').contract;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ContractHandoverCard(
              contract: model,
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(HandoverThumbnail));
    await tester.tap(find.byType(HandoverThumbnail));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.tap(find.byType(HandoverThumbnail));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(repository.imageRequests, 1);
  });
  testWidgets(
    'tracking chips cannot change Backend status, refresh fetches the same ID',
    (tester) async {
      final repository = QueuedRepository();
      final model = ContractDetailData.fromJson(fixture(), 'HDTEST').contract;
      await tester.pumpWidget(
        MaterialApp(
          home: ContractTrackingPage(contract: model, repository: repository),
        ),
      );
      repository.requests[0].complete(fixture());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đang thuê').first);
      await tester.pumpAndSettle();
      expect(find.text('TRẠNG THÁI HIỆN TẠI: CHỜ BÀN GIAO'), findsOneWidget);
      final refresh =
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
      repository.requests[1].complete(fixture(status: 'DANG_THUE'));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('TRẠNG THÁI HIỆN TẠI: ĐANG THUÊ'), findsOneWidget);
      expect(find.text('Mã HĐ: HDTEST'), findsOneWidget);
      final failed =
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
      repository.requests[2].completeError(Exception('Offline'));
      await failed;
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('TRẠNG THÁI HIỆN TẠI: ĐANG THUÊ'), findsOneWidget);
    },
  );
  testWidgets(
    'detail refresh failure keeps serials; foreground reload and dispose are safe',
    (tester) async {
      final repository = QueuedRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ContractPage(contractId: 'HDTEST', repository: repository),
        ),
      );
      repository.requests[0].complete(fixture());
      await tester.pumpAndSettle();
      final refresh =
          tester
              .widget<RefreshIndicator>(find.byType(RefreshIndicator))
              .onRefresh();
      repository.requests[1].completeError(Exception('Offline'));
      await refresh;
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Serial: SERIAL1'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(repository.requests.length, 3);
      await tester.pumpWidget(const SizedBox());
      repository.requests[2].complete(fixture(status: 'DANG_THUE'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  test('overlapping normal reload triggers share one GET', () async {
    final repository = QueuedRepository();
    final cubit = ContractDetailCubit(contractId: 'HDTEST', repository: repository);
    final first = cubit.load();
    final second = cubit.load();
    expect(repository.requests.length, 1);
    repository.requests.single.complete(fixture());
    await Future.wait([first, second]);
    expect(cubit.state.data!.contract.contractId, 'HDTEST');
    await cubit.close();
  });
  test('relative evidence URLs use the configured API client without token query parameters', () async {
    RequestOptions? captured;
    final dio = Dio(BaseOptions(headers: {'Authorization': 'fixture-only'}));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      captured = options;
      handler.resolve(Response<List<int>>(requestOptions: options, data: [1, 2], statusCode: 200));
    }));
    final repository = ContractRepository(dio: dio);
    expect(await repository.getHandoverImage('/api/photos/one.jpg'), [1, 2]);
    expect(captured!.uri.origin, Uri.parse(ApiConfig.baseUrl).origin);
    expect(captured!.uri.path, '/api/photos/one.jpg');
    expect(captured!.uri.query, isEmpty);
    expect(captured!.headers.containsKey('Authorization'), isTrue);
    expect(captured!.followRedirects, isFalse);
    expect(() => repository.getHandoverImage('javascript:alert(1)'), throwsFormatException);
    dio.close();
  });
}
