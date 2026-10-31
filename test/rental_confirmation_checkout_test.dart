import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/features/cart/domain/models/cart_item_model.dart';
import 'package:rentcam/features/cart/data/repositories/dio_cart_repository.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/features/rental/bloc/rental_bloc.dart';
import 'package:rentcam/features/rental_confirmation/presentation/rental_confirmation_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rentcam/core/widgets/reservation_timer.dart';
import 'package:rentcam/features/rental_confirmation/presentation/bottom_sheets/change_branch_bottom_sheet.dart';

class _Rental extends RentalBloc {
  void show(RentalState value) => emit(value);
}

CartItemModel item({String id = 'DONG001', String name = 'Canon EOS R6'}) =>
    CartItemModel(
      id: 'CART-$id',
      version: 'version-$id',
      branchId: 'CH001',
      branchName: 'Quận 1',
      modelId: id,
      modelName: name,
      imageUrl: '',
      dailyPrice: 500000,
      depositPrice: 5000000,
      startDate: DateTime(2026, 11, 23, 8),
      endDate: DateTime(2026, 11, 25, 8),
      rentalDays: 2,
      quantity: 1,
    );

Map<String, dynamic> hold(List<CartItemModel> items) => {
  'maGiuCho': 'GC-OFFLINE',
  'trangThai': 'DANG_GIU',
  'hetHanLuc': '2026-11-01T02:20:00Z',
  'thoiGianServer': '2026-11-01T02:00:00Z',
  'daXacNhanThongTin': true,
  'baoGia': [
    for (final line in items)
      {
        'soLuong': line.quantity,
        'donGiaSauGiam': 500000,
        'tongTienThue': 1000000,
        'tongTienCoc': 5000000,
      },
  ],
};

void main() {
  late _Rental bloc;
  late InterceptorsWrapper fake;
  late List<RequestOptions> calls;
  late String editMode;
  late Map<String, dynamic> serverSnapshot;
  Completer<void>? slowEdit;
  Completer<void>? slowAvailability;
  Completer<void>? lateStatus;
  setUpAll(() => initializeDateFormatting('vi_VN'));
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'offline-test-session',
    });
    calls = [];
    editMode = 'success';
    slowEdit = null;
    slowAvailability = null;
    lateStatus = null;
    fake = InterceptorsWrapper(
      onRequest: (options, handler) async {
        calls.add(options);
        Object data;
        if (options.path == '/api/gio-hang/giu-cho/GC-OFFLINE' &&
            options.method == 'PUT') {
          if (slowEdit != null &&
              calls.where((r) => r.method == 'PUT').length == 1) {
            await slowEdit!.future;
          }
          if (editMode == 'insufficient') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'code': 'INSUFFICIENT_DEVICES',
                    'loi': 'Không đủ thiết bị; giữ lựa chọn cũ.',
                  },
                ),
              ),
            );
            return;
          }
          if (editMode != 'timeout_unreachable') {
            final body = options.data as Map;
            serverSnapshot = snapshot(
              [item()],
              branch: body['maCuaHang'] as String,
              pickup: body['ngayBatDau'] as String,
              dropoff: body['ngayKetThuc'] as String,
              version: 'new-version',
            );
            final timeChanged =
                DateTime.parse(body['ngayBatDau'] as String) !=
                    DateTime(2026, 11, 23, 8) ||
                DateTime.parse(body['ngayKetThuc'] as String) !=
                    DateTime(2026, 11, 25, 8);
            serverSnapshot['thoiGianServer'] = '2026-11-01T02:07:00Z';
            serverSnapshot['hetHanLuc'] =
                timeChanged ? '2026-11-01T02:27:00Z' : '2026-11-01T02:20:00Z';
          }
          if (editMode.startsWith('timeout')) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          }
          data = serverSnapshot;
        } else if (options.path == '/api/giu-cho/GC-OFFLINE') {
          if (lateStatus != null) {
            final frozen = Map<String, dynamic>.from(serverSnapshot);
            frozen['thoiGianServer'] = '2026-11-01T02:09:00Z';
            await lateStatus!.future;
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: frozen),
            );
            return;
          }
          if (editMode == 'timeout_unreachable') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          data = serverSnapshot;
        } else if (options.path == '/api/lich-trong') {
          if (slowAvailability != null &&
              options.queryParameters['maCuaHang'] == 'CH001') {
            await slowAvailability!.future;
          }
          data = {'soLuongConTrong': editMode == 'branch_unavailable' ? 0 : 1};
        } else if (options.path == '/api/tam-tinh') {
          data = {
            'soNgayTinhPhi': 2,
            'giaThueNgay': 500000,
            'tongTienThue': 1000000,
            'tongTienCoc': 5000000,
            'phanTramGiamGia': 0,
          };
        } else if (options.path == '/api/giu-cho/GC-OFFLINE/xac-nhan-thue') {
          data = {'maHopDong': 'HD-OFFLINE'};
        } else if (options.path == '/api/lich-trong/thang') {
          final year = options.queryParameters['nam'] as int;
          final month = options.queryParameters['thang'] as int;
          data = {
            'ngayList': [
              for (var day = 1; day <= 28; day++)
                {
                  'ngay': DateTime(year, month, day).toIso8601String(),
                  'trangThai': 'XANH',
                },
            ],
          };
        } else if (options.path == '/api/dong-may/DONG001') {
          data = {
            'maDongMay': 'DONG001',
            'tenDongMay': 'Canon EOS R6',
            'tenThuongHieu': 'Canon',
            'tenDanhMuc': 'Máy ảnh',
            'giaThueNgay': 500000,
            'tienCoc': 5000000,
            'phanTramGiamGia': 0,
            'anh': [],
            'tonKho': [
              {'maCuaHang': 'CH001', 'sanSang': 1},
              {'maCuaHang': 'CH002', 'sanSang': 1},
            ],
          };
        } else if (options.path == '/api/dong-may/DONG001/danh-gia') {
          data = {'diemTrungBinh': 0, 'tongSo': 0, 'duLieu': []};
        } else if (options.path == '/api/cua-hang') {
          data = <dynamic>[
            {'maCuaHang': 'CH001', 'tenCuaHang': 'Quận 1', 'diaChi': ''},
            {'maCuaHang': 'CH002', 'tenCuaHang': 'Chi nhánh 2', 'diaChi': ''},
          ];
        } else {
          throw StateError(
            'Unexpected offline request: ${options.method} ${options.path}',
          );
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
        );
      },
    );
    ApiClient.instance.interceptors.add(fake);
    bloc = _Rental();
  });
  tearDown(() async {
    await bloc.close();
    ApiClient.instance.interceptors.remove(fake);
  });

  Future<void> adopt(List<CartItemModel> items) async {
    serverSnapshot = snapshot(items);
    final ready = bloc.stream.firstWhere(
      (state) => state.maGiuCho == 'GC-OFFLINE',
    );
    bloc.add(AdoptCartCheckout(hold(items), items));
    await ready;
  }

  test(
    'initialization does not choose the first branch and preserves an explicit selection',
    () async {
      await adopt([item()]);
      final device = bloc.state.selectedDevice!;
      final cleared = bloc.stream.firstWhere((s) => s.selectedDevice == null);
      bloc.add(const ClearRentalState());
      await cleared;
      final initialized = bloc.stream.firstWhere(
        (s) => s.selectedDevice != null,
      );
      bloc.add(InitializeRental(device));
      await initialized;
      expect(bloc.state.branchId, isNull);
      final selected = bloc.stream.firstWhere((s) => s.branchId == 'CH002');
      bloc.add(const UpdateRentalBranch('CH002'));
      await selected;
      bloc.add(InitializeRental(device));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.branchId, 'CH002');
      final invalidated = bloc.stream.firstWhere((s) => s.branchId == null);
      bloc.add(
        InitializeRental(
          device.copyWith(
            branches:
                device.branches.where((b) => b.branchId == 'CH001').toList(),
          ),
        ),
      );
      await invalidated;
      expect(bloc.state.priceQuote, isNull);
    },
  );

  testWidgets(
    'one valid branch is explicit and missing selection is not replaced with the first',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      final only = bloc.state.selectedDevice!.branches.take(1).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeBranchBottomSheet(
              currentBranchId: null,
              branches: only,
              loadBranches: () async => only,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Chỉ có một chi nhánh đáp ứng lựa chọn hiện tại.'),
        findsOneWidget,
      );
      PrimaryButton apply() => tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Áp dụng'),
      );
      expect(apply().onPressed, isNull);
      await tester.tap(find.text(only.single.branchName));
      await tester.pump();
      expect(apply().onPressed, isNotNull);
      expect(calls.where((r) => r.method != 'GET'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'branch candidates exclude a branch without capacity and retain the owned hold',
    () async {
      await adopt([item()]);
      editMode = 'branch_unavailable';
      expect((await bloc.eligibleBranches()).map((b) => b.branchId), ['CH001']);
      expect(calls.any((r) => r.method != 'GET'), isFalse);
    },
  );

  test(
    'a late resume response cannot restore the old hold countdown after an edit',
    () async {
      await adopt([item()]);
      lateStatus = Completer<void>();
      final syncing = bloc.stream.firstWhere((s) => s.isSyncingReservation);
      bloc.add(const FetchActiveReservation());
      await syncing;
      expect(bloc.state.isValidToRent, isFalse);
      final edited = bloc.stream.firstWhere(
        (s) => s.branchId == 'CH002' && !s.isChecking,
      );
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: item().startDate,
          dropoff: DateTime(2026, 11, 26, 8),
        ),
      );
      await edited;
      lateStatus!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 20));
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.returnDate, DateTime(2026, 11, 26, 8));
      expect(bloc.state.isSyncingReservation, isFalse);
    },
  );

  test(
    'an old availability response cannot replace the latest branch or quote',
    () async {
      await adopt([item()]);
      final device = bloc.state.selectedDevice!;
      final cleared = bloc.stream.firstWhere((s) => s.selectedDevice == null);
      bloc.add(const ClearRentalState());
      await cleared;
      final initialized = bloc.stream.firstWhere(
        (s) => s.selectedDevice != null,
      );
      bloc.add(InitializeRental(device));
      await initialized;
      final dates = bloc.stream.firstWhere((s) => s.pickupDate != null);
      bloc.add(
        UpdateRentalPeriod(
          pickupDate: item().startDate,
          returnDate: item().endDate,
        ),
      );
      await dates;
      slowAvailability = Completer<void>();
      bloc.add(const UpdateRentalBranch('CH001'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final latest = bloc.stream.firstWhere(
        (s) => s.branchId == 'CH002' && s.priceQuote != null && !s.isChecking,
      );
      bloc.add(const UpdateRentalBranch('CH002'));
      await latest;
      slowAvailability!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.isValidToRent, isTrue);
      final quotes = calls.where((r) => r.path == '/api/tam-tinh').toList();
      expect(quotes, hasLength(1));
      expect(quotes.single.queryParameters['maCuaHang'], 'CH002');
      expect(calls.where((r) => r.method != 'GET'), isEmpty);
    },
  );

  test(
    'rapid held edits serialize writes and apply the latest queued selection',
    () async {
      await adopt([item()]);
      slowEdit = Completer<void>();
      final done = bloc.stream.firstWhere(
        (s) => !s.isChecking && s.returnDate == DateTime(2026, 11, 28, 8),
      );
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: item().startDate,
          dropoff: DateTime(2026, 11, 26, 8),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(
        UpdateCartHold(
          branchId: 'CH001',
          pickup: item().startDate,
          dropoff: DateTime(2026, 11, 27, 8),
        ),
      );
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: item().startDate,
          dropoff: DateTime(2026, 11, 28, 8),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const CreateContract());
      slowEdit!.complete();
      await done.timeout(const Duration(seconds: 3));
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.isCriteriaMatchingReservation, isTrue);
      final writes = calls.where((r) => r.method == 'PUT').toList();
      expect(writes, hasLength(2));
      expect((writes.last.data as Map)['items'], [
        {'id': 'CART-DONG001', 'phienBan': 'new-version'},
      ]);
      expect(calls.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'invalid period does not mutate the hold and successful confirmation cannot post twice',
    () async {
      await adopt([item()]);
      final invalid = bloc.stream.firstWhere((s) => s.cartEditError != null);
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: item().startDate,
          dropoff: item().startDate,
        ),
      );
      await invalid;
      expect(calls.where((r) => r.method == 'PUT'), isEmpty);
      final confirmed = bloc.stream.firstWhere((s) => s.isConfirmed);
      bloc.add(const ToggleConfirmation(true));
      await confirmed;
      final created = bloc.stream.firstWhere(
        (s) => s.contractId == 'HD-OFFLINE',
      );
      bloc.add(const CreateContract());
      await created;
      bloc.add(const CreateContract());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  Future<GoRouter> render(WidgetTester tester) async {
    // Build the interactive Bloc in the widget test clock zone.
    final loaded = bloc.state;
    await tester.runAsync(() => bloc.close());
    bloc = _Rental()..show(loaded);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const RentalConfirmationView()),
        GoRoute(
          path: '/device/:id',
          builder:
              (_, state) => Scaffold(
                body: Text(
                  'DETAIL:${state.pathParameters['id']}:${state.uri.queryParameters['reviewMode']}',
                ),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<RentalBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  test(
    'cart adoption saves the server-held criteria and Backend money without a fabricated percentage',
    () async {
      await adopt([item()]);
      final state = bloc.state;
      expect(state.isCriteriaMatchingReservation, isTrue);
      expect(state.reservedBranchId, 'CH001');
      expect(state.reservedPickupDate, DateTime(2026, 11, 23, 8));
      expect(state.reservedReturnDate, DateTime(2026, 11, 25, 8));
      expect(state.reservedQuantity, 1);
      expect(state.subtotal, 1000000);
      expect(state.deposit, 5000000);
      expect(state.totalPayment, 6000000);
      expect(
        state.copyWith(quantity: 2).isCriteriaMatchingReservation,
        isFalse,
      );
      expect(
        state.copyWith(branchId: 'CH002').isCriteriaMatchingReservation,
        isFalse,
      );
      expect(
        state
            .copyWith(returnDate: DateTime(2026, 11, 26, 8))
            .isCriteriaMatchingReservation,
        isFalse,
      );
      expect(calls.every((request) => request.method == 'GET'), isTrue);
    },
  );

  testWidgets(
    'confirmed cart can continue, mismatched or expired hold stays blocked, 20 percent is absent',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      await render(tester);
      expect(
        find.text(
          'Thông tin thuê đã thay đổi, không khớp với lượt giữ chỗ hiện tại.',
        ),
        findsNothing,
      );
      expect(find.text('20%'), findsNothing);
      expect(find.text('Mức cọc từng mẫu × số lượng'), findsOneWidget);
      PrimaryButton button() => tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Tiếp tục lập hợp đồng →'),
      );
      expect(button().onPressed, isNull);
      final checkbox = find.byType(Checkbox);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(bloc.state.isConfirmed, isTrue);
      expect(button().onPressed, isNotNull);
      final good = bloc.state;
      bloc.show(good.copyWith(quantity: 2));
      await tester.pumpAndSettle();
      expect(button().onPressed, isNull);
      expect(
        find.text(
          'Thông tin thuê đã thay đổi, không khớp với lượt giữ chỗ hiện tại.',
        ),
        findsOneWidget,
      );
      bloc.show(good.copyWith(isReservationExpired: true));
      await tester.pumpAndSettle();
      final remainingButton = find.widgetWithText(
        PrimaryButton,
        'Tiếp tục lập hợp đồng →',
      );
      if (remainingButton.evaluate().isNotEmpty) {
        expect(tester.widget<PrimaryButton>(remainingButton).onPressed, isNull);
      }
      expect(calls.every((request) => request.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'device details navigates to the real rented model in review mode',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      await render(tester);
      final action = find.text('Xem chi tiết');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:DONG001:true'), findsOneWidget);
      expect(calls.any((r) => r.path.contains('sony_a7iv')), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'multi-model cart details lets the customer choose the actual model',
    (tester) async {
      await tester.runAsync(
        () => adopt([item(), item(id: 'DONG002', name: 'Ống kính test')]),
      );
      await render(tester);
      expect(bloc.state.reservedQuantity, 2);
      final action = find.text('Xem chi tiết');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Chọn thiết bị để xem'), findsOneWidget);
      await tester.tap(find.text('Ống kính test'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL:DONG002:true'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final (index, title) in [
    (0, 'Chọn thời gian thuê'),
    (1, 'Thay đổi chi nhánh'),
  ]) {
    testWidgets(
      '$title opens the existing editor; closing does not mutate the hold',
      (tester) async {
        await tester.runAsync(() => adopt([item()]));
        await render(tester);
        final initial = bloc.state;
        final action = find.text('Thay đổi').at(index);
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        final cancel = find.text('Hủy');
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(bloc.state, initial);
        expect(calls.every((request) => request.method == 'GET'), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  Future<void> applyEdit() async {
    final done = bloc.stream.firstWhere((state) => !state.isChecking);
    bloc.add(
      UpdateCartHold(
        branchId: 'CH002',
        pickup: DateTime(2026, 11, 23, 8),
        dropoff: DateTime(2026, 11, 26, 8),
      ),
    );
    await done;
  }

  test(
    'time edit uses one versioned PUT and reanchors countdown to the new server deadline',
    () async {
      await adopt([item()]);
      final watch = bloc.reservationStopwatch;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final elapsed = watch.elapsed;
      await applyEdit();
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.cartItems.single.version, 'new-version');
      expect(bloc.state.reservedReturnDate, DateTime(2026, 11, 26, 8));
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 20));
      expect(identical(bloc.reservationStopwatch, watch), isTrue);
      expect(watch.elapsed, lessThan(elapsed));
      expect(bloc.state.isConfirmed, isFalse);
      expect(bloc.state.subtotal, 1500000);
      expect(bloc.state.cartEditError, contains('Báo giá đã thay đổi'));
      expect(bloc.state.deposit, 5000000);
      final put = calls.singleWhere((request) => request.method == 'PUT');
      expect((put.data as Map)['items'], [
        {'id': 'CART-DONG001', 'phienBan': 'version-DONG001'},
      ]);
      expect((put.data as Map).keys, isNot(contains('tongTienCoc')));
      expect(calls.any((request) => request.method == 'POST'), isFalse);
    },
  );

  test(
    'branch-only update synchronizes remaining time without receiving a new expiry',
    () async {
      await adopt([item()]);
      final done = bloc.stream.firstWhere((state) => !state.isChecking);
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: item().startDate,
          dropoff: item().endDate,
        ),
      );
      await done;
      expect(serverSnapshot['hetHanLuc'], '2026-11-01T02:20:00Z');
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 13));
    },
  );

  test(
    'GET reconciliation counts down the same expiry and never requests an update',
    () async {
      await adopt([item()]);
      serverSnapshot['thoiGianServer'] = '2026-11-01T02:09:00Z';
      final done = bloc.stream.firstWhere((state) => !state.isChecking);
      bloc.add(const ReconcileCartHold());
      await done;
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 11));
      expect(serverSnapshot['hetHanLuc'], '2026-11-01T02:20:00Z');
      expect(calls.where((request) => request.method == 'PUT'), isEmpty);
    },
  );

  test(
    'unchanged Apply adopts the remaining server time without resetting the deadline',
    () async {
      await adopt([item()]);
      final done = bloc.stream.firstWhere((state) => !state.isChecking);
      bloc.add(
        UpdateCartHold(
          branchId: 'CH001',
          pickup: item().startDate,
          dropoff: item().endDate,
        ),
      );
      await done;
      expect(serverSnapshot['hetHanLuc'], '2026-11-01T02:20:00Z');
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 13));
    },
  );

  testWidgets(
    'countdown widget replaces its anchor after a successful time edit',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      await render(tester);
      final oldKey =
          tester.widget<ReservationTimer>(find.byType(ReservationTimer)).key;
      bloc.add(
        UpdateCartHold(
          branchId: 'CH002',
          pickup: DateTime(2026, 11, 23, 8),
          dropoff: DateTime(2026, 11, 26, 8),
        ),
      );
      await tester.pumpAndSettle();
      final timer = tester.widget<ReservationTimer>(
        find.byType(ReservationTimer),
      );
      expect(timer.key, isNot(oldKey));
      expect(timer.initialTimeRemaining, const Duration(minutes: 20));
      expect(
        bloc.state.reservationServerTime,
        DateTime.parse('2026-11-01T02:07:00Z'),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'unavailable edit keeps all old criteria, prices, selected versions and countdown',
    () async {
      await adopt([item()]);
      final original = bloc.state;
      editMode = 'insufficient';
      await applyEdit();
      expect(bloc.state.branchId, original.branchId);
      expect(bloc.state.returnDate, original.returnDate);
      expect(bloc.state.cartItems, original.cartItems);
      expect(bloc.state.priceQuote, original.priceQuote);
      expect(bloc.state.initialTimeRemaining, original.initialTimeRemaining);
      expect(bloc.state.cartEditNeedsReconciliation, isFalse);
      expect(bloc.state.isValidToRent, isTrue);
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
    },
  );

  test(
    'timeout after commit reconciles only with GET and adopts the actual version',
    () async {
      await adopt([item()]);
      editMode = 'timeout_committed';
      await applyEdit();
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.cartItems.single.version, 'new-version');
      expect(bloc.state.cartEditNeedsReconciliation, isFalse);
      expect(bloc.state.initialTimeRemaining, const Duration(minutes: 20));
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
      expect(
        calls.where((request) => request.path == '/api/giu-cho/GC-OFFLINE'),
        hasLength(1),
      );
    },
  );

  test(
    'uncertain PUT and failed GET block further writes and contract creation until GET succeeds',
    () async {
      await adopt([item()]);
      editMode = 'timeout_unreachable';
      await applyEdit();
      expect(bloc.state.cartEditNeedsReconciliation, isTrue);
      expect(bloc.state.isValidToRent, isFalse);
      await applyEdit(); // Reconcile only; never repeats the PUT.
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
      bloc.add(const CreateContract());
      await Future<void>.delayed(Duration.zero);
      expect(calls.any((request) => request.method == 'POST'), isFalse);
      editMode = 'success';
      final done = bloc.stream.firstWhere((state) => !state.isChecking);
      bloc.add(const ReconcileCartHold());
      await done;
      expect(bloc.state.cartEditNeedsReconciliation, isFalse);
      expect(bloc.state.branchId, 'CH001');
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
    },
  );
  test(
    'cart checkout recovers the same edited hold with new selected versions, without a second POST',
    () async {
      var edited = false;
      var posts = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            final current = snapshot([
              item(),
            ], version: edited ? 'new-version' : null);
            Object data;
            if (request.path == '/api/gio-hang') {
              data = current['cartItems']!;
            } else if (request.method == 'POST' &&
                request.path == '/api/gio-hang/checkout') {
              posts++;
              data = current;
            } else if (request.method == 'GET' &&
                request.path.startsWith('/api/gio-hang/checkout/')) {
              data = current;
            } else {
              throw StateError('Unexpected local request');
            }
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: data),
            );
          },
        ),
      );
      final repository = DioCartRepository(dio: dio);
      await repository.checkout(await repository.getCartItems());
      edited = true;
      final recovered = await repository.checkout(
        await repository.getCartItems(),
      );
      expect(recovered['maGiuCho'], 'GC-OFFLINE');
      expect(posts, 1);
      await repository.checkout(await repository.getCartItems());
      expect(posts, 1);
    },
  );

  testWidgets(
    'branch selection stays local until Apply updates the hold once',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      await render(tester);
      expect(
        bloc.state.selectedDevice!.branches.map((branch) => branch.branchId),
        contains('CH002'),
      );
      final change = find.text('Thay đổi').at(1);
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chi nhánh 2'));
      await tester.pump();
      expect(calls.any((request) => request.method != 'GET'), isFalse);
      final apply = find.widgetWithText(PrimaryButton, 'Áp dụng');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(bloc.state.branchId, 'CH002');
      expect(bloc.state.cartItems.single.version, 'new-version');
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
      expect(calls.any((request) => request.method == 'POST'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'date edit reuses the calendar and applies the selected 08:00 times once',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      await render(tester);
      final change = find.text('Thay đổi').first;
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      final calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((widget) => widget is TableCalendar),
      );
      calendar.onRangeSelected!(
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 26),
        DateTime(2026, 11, 23),
      );
      await tester.pump();
      expect(calls.any((request) => request.method != 'GET'), isFalse);
      final apply = find.widgetWithText(PrimaryButton, 'Áp dụng');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(bloc.state.returnDate, DateTime(2026, 11, 26, 8));
      expect(bloc.state.cartItems.single.version, 'new-version');
      expect(calls.where((request) => request.method == 'PUT'), hasLength(1));
      expect(calls.any((request) => request.method == 'POST'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'confirmation preserves fractional Backend amounts with the shared money formatter',
    (tester) async {
      await tester.runAsync(() => adopt([item()]));
      bloc.show(
        bloc.state.copyWith(
          priceQuote: {
            'soNgayTinhPhi': 2,
            'giaThueNgay': 100.25,
            'tongTienThue': 200.50,
            'tongTienCoc': 500.75,
            'phanTramGiamGia': 0,
          },
        ),
      );
      await render(tester);
      const money = AppMoneyFormatter();
      expect(find.textContaining(money.format(100.25)), findsNWidgets(2));
      expect(find.text(money.format(500.75)), findsNWidgets(2));
      expect(find.text(money.format(701.25)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Map<String, dynamic> snapshot(
  List<CartItemModel> items, {
  String branch = 'CH001',
  String pickup = '2026-11-23T08:00:00',
  String dropoff = '2026-11-25T08:00:00',
  String? version,
}) {
  final days =
      DateTime.parse(dropoff).difference(DateTime.parse(pickup)).inDays;
  Map<String, dynamic> quote(CartItemModel item) => {
    'soLuong': item.quantity,
    'donGiaSauGiam': 500000,
    'soNgayTinhPhi': days,
    'tongTienThue': 500000 * days,
    'tienCocMotDonVi': 5000000,
    'tongTienCoc': 5000000,
  };
  return {
    ...hold(items),
    'maCuaHang': branch,
    'baoGia': [for (final item in items) quote(item)],
    'cartItems': [
      for (final item in items)
        {
          'maChiTietGioHang': item.id,
          'phienBan': version ?? item.version,
          'maCuaHang': branch,
          'tenCuaHang': 'Chi nhánh',
          'maDongMay': item.modelId,
          'tenDongMay': item.modelName,
          'soLuong': item.quantity,
          'ngayBatDau': pickup,
          'ngayKetThuc': dropoff,
          'baoGia': quote(item),
          'khaDung': true,
          'soLuongConTrong': item.quantity,
        },
    ],
  };
}
