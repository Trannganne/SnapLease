import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/data/mock/mock_device_detail_repository.dart';
import 'package:rentcam/domain/entities/device_detail.dart';
import 'package:rentcam/features/catalog/data/catalog_repository.dart';
import 'package:rentcam/features/cart/data/repositories/dio_cart_repository.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/device_detail/data/device_detail_repository.dart';
import 'package:rentcam/features/payment/bloc/payment_bloc.dart';
import 'package:rentcam/features/payment/bloc/payment_event.dart';
import 'package:rentcam/features/payment/bloc/payment_state.dart';
import 'package:rentcam/features/payment/data/payment_repository.dart';
import 'package:rentcam/features/payment/domain/models/payment_model.dart';
import 'package:rentcam/features/payment/presentation/payment_page.dart';
import 'package:rentcam/features/payment/presentation/payment_result_page.dart';
import 'package:rentcam/features/rental/bloc/rental_bloc.dart';
import 'package:rentcam/features/rental_confirmation/presentation/rental_confirmation_page.dart';
import 'contract_handover_test.dart' show fixture;
import 'rental_confirmation_checkout_test.dart'
    as rental_fixture
    show item, snapshot;

// All requests terminate here. No API, database or payment provider is contacted.
class _Http implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  final requests = <RequestOptions>[];
  late final Dio dio = Dio(BaseOptions(baseUrl: 'http://offline.invalid'))
    ..httpClientAdapter = this;
  _Http(this.reply);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return await reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, dynamic> _hold({String status = 'DANG_GIU'}) => {
  ...rental_fixture.snapshot([
    rental_fixture.item(),
  ], version: 'server-version'),
  'trangThai': status,
};

class _Rental extends RentalBloc {
  _Rental(Dio dio, {DeviceDetailRepository? repository})
    : super(
        repository: repository ?? DeviceDetailRepository(dio: dio),
        cartRepository: DioCartRepository(dio: dio),
      );
  void seed(RentalState value) => emit(value);
}

class _Cancellation extends DeviceDetailRepository {
  final entered = Completer<void>();
  final result = Completer<void>();
  @override
  Future<void> cancelReservation(String id) {
    entered.complete();
    return result.future;
  }
}

Future<RentalState> _until(
  _Rental bloc,
  bool Function(RentalState) predicate,
) =>
    predicate(bloc.state)
        ? Future.value(bloc.state)
        : bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeviceDetail device;
  setUpAll(() async {
    device = await MockDeviceDetailRepository().getDeviceDetail('DONG001');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'offline-account-A',
    });
    TokenStorage.beforeSessionChange = null;
    TokenStorage.sessionCleanups.clear();
  });
  RentalState ready({bool held = false}) => RentalState(
    selectedDevice: device,
    branchId: 'CH001',
    pickupDate: DateTime(2026, 11, 23, 8),
    returnDate: DateTime(2026, 11, 25, 8),
    quantity: 1,
    availableQuantity: 1,
    priceQuote: const {
      'soNgayTinhPhi': 2,
      'giaThueNgay': 500000,
      'tongTienThue': 1000000,
      'tongTienCoc': 5000000,
      'phanTramGiamGia': 0,
    },
    maGiuCho: held ? 'GC-OFFLINE' : null,
    cartItems: held ? [rental_fixture.item()] : const [],
  );
  Future<Map<String, dynamic>> reserve(
    DeviceDetailRepository repository, {
    String key = 'attempt-A',
    int quantity = 1,
  }) => repository.createReservation(
    maCuaHang: 'CH001',
    maDongMay: 'DONG001',
    soLuong: quantity,
    ngayBatDau: DateTime(2026, 11, 23, 8),
    ngayKetThuc: DateTime(2026, 11, 25, 8),
    idempotencyKey: key,
  );

  test(
    'catalog sends supported filters and pagination; total comes from Backend',
    () async {
      final http = _Http(
        (r) => _json({
          'tongSo': 43,
          'trang': 2,
          'kichThuocTrang': 1,
          'duLieu': [
            {
              'maDongMay': 'DM1',
              'tenDongMay': 'Camera',
              'giaThueNgay': 100.25,
              'anhDaiDien': null,
              'rating': 0,
              'reviewCount': 0,
              'available': true,
              'tenDanhMuc': 'Máy ảnh',
              'branchIds': ['CH001'],
            },
          ],
        }),
      );
      final result = await CatalogRepository(dio: http.dio).getProducts(
        keyword: 'Sony',
        categoryId: 'CAT',
        brandId: 'BRAND',
        branchId: 'CH001',
        page: 2,
        pageSize: 1,
      );
      expect(http.requests.single.path, '/api/dong-may');
      expect(http.requests.single.queryParameters, {
        'tuKhoa': 'Sony',
        'maDanhMuc': 'CAT',
        'maThuongHieu': 'BRAND',
        'maCuaHang': 'CH001',
        'trang': 2,
        'kichThuocTrang': 1,
      });
      expect(result['tongSo'], 43);
      expect((result['products'] as List).single.id, 'DM1');
    },
  );

  test(
    'availability and quote use model/store, quantity and Vietnamese wall-clock',
    () async {
      final http = _Http(
        (r) => _json(
          r.path == '/api/lich-trong'
              ? {'soLuongConTrong': 2}
              : {'tongTienThue': 100.25, 'tongTienCoc': 200.50},
        ),
      );
      final repository = DeviceDetailRepository(dio: http.dio);
      final start = DateTime(2026, 11, 23, 8), end = DateTime(2026, 11, 25, 8);
      expect(
        await repository.checkAvailability('CH001', 'DONG001', start, end),
        2,
      );
      final quote = await repository.getPriceQuote(
        'CH001',
        'DONG001',
        2,
        start,
        end,
      );
      expect(quote['tongTienThue'], 100.25);
      for (final request in http.requests) {
        expect(request.queryParameters['ngayBatDau'], '2026-11-23T08:00:00');
        expect(request.queryParameters['ngayKetThuc'], '2026-11-25T08:00:00');
        expect(request.queryParameters['maDongMay'], 'DONG001');
        expect(request.queryParameters['maCuaHang'], 'CH001');
      }
      expect(http.requests.last.queryParameters['soLuong'], 2);
    },
  );

  test(
    'direct hold timeout persists its key across repositories; no automatic POST retry',
    () async {
      var posts = 0;
      final http = _Http((r) {
        if (r.method == 'GET') return _json(_hold());
        if (++posts == 1) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json({'maGiuCho': 'GC-OFFLINE', 'trangThai': 'DANG_GIU'}, 201);
      });
      await expectLater(
        reserve(DeviceDetailRepository(dio: http.dio)),
        throwsA(isA<RentalRequestFailure>()),
      );
      expect(posts, 1);
      await reserve(
        DeviceDetailRepository(dio: http.dio),
        key: 'new-process-key',
      );
      expect(
        http.requests
            .where((r) => r.method == 'POST')
            .map((r) => r.headers['Idempotency-Key']),
        ['attempt-A', 'attempt-A'],
      );
      await reserve(DeviceDetailRepository(dio: http.dio), key: 'another-key');
      expect(
        posts,
        2,
        reason: 'Known hold is recovered by GET, without another POST.',
      );
    },
  );

  test(
    'different payload cannot bypass an unresolved direct hold attempt',
    () async {
      final http = _Http(
        (r) =>
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.receiveTimeout,
            ),
      );
      final repository = DeviceDetailRepository(dio: http.dio);
      await expectLater(
        reserve(repository),
        throwsA(isA<RentalRequestFailure>()),
      );
      await expectLater(
        reserve(repository, quantity: 2),
        throwsA(isA<RentalRequestFailure>()),
      );
      expect(http.requests, hasLength(1));
    },
  );

  test(
    'definitive capacity conflict permits an explicit corrected request',
    () async {
      var count = 0;
      final http = _Http(
        (r) =>
            ++count == 1
                ? _json({
                  'loi': 'Không đủ thiết bị.',
                  'code': 'INSUFFICIENT_DEVICES',
                }, 409)
                : _json({
                  'maGiuCho': 'GC-OFFLINE',
                  'trangThai': 'DANG_GIU',
                }, 201),
      );
      final repository = DeviceDetailRepository(dio: http.dio);
      await expectLater(
        reserve(repository, quantity: 2),
        throwsA(isA<RentalRequestFailure>()),
      );
      await reserve(repository, quantity: 1);
      expect(http.requests.last.data['soLuong'], 1);
    },
  );

  test(
    'double submit creates one hold and adopts server versions and UTC deadline',
    () async {
      final entered = Completer<void>(), reply = Completer<ResponseBody>();
      final http = _Http((r) {
        if (r.method == 'POST') {
          entered.complete();
          return reply.future;
        }
        return _json(_hold());
      });
      final bloc = _Rental(http.dio)..seed(ready());
      addTearDown(bloc.close);
      bloc
        ..add(const CreateReservation())
        ..add(const CreateReservation());
      await entered.future.timeout(const Duration(seconds: 3));
      expect(http.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(bloc.state.maGiuCho, isNull);
      reply.complete(_json({'maGiuCho': 'GC-OFFLINE'}, 201));
      final result = await _until(
        bloc,
        (s) => s.maGiuCho != null && !s.isCreatingReservation,
      );
      expect(result.cartItems.single.version, 'server-version');
      expect(result.initialTimeRemaining, const Duration(minutes: 20));
      expect(result.isCriteriaMatchingReservation, isTrue);
    },
  );

  test(
    'a late availability response cannot replace the latest branch and quote',
    () async {
      final entered = Completer<void>(), old = Completer<ResponseBody>();
      final http = _Http((r) {
        if (r.path == '/api/lich-trong') {
          if (r.queryParameters['maCuaHang'] == 'CH001') {
            entered.complete();
            return old.future;
          }
          return _json({'soLuongConTrong': 2});
        }
        return _json({'soNgayTinhPhi': 2, 'tongTienThue': 200.25});
      });
      final bloc = _Rental(http.dio)..seed(ready());
      addTearDown(bloc.close);
      bloc.add(const FetchAvailabilityAndQuote());
      await entered.future.timeout(const Duration(seconds: 3));
      bloc.add(const UpdateRentalBranch('CH002'));
      await _until(bloc, (s) => s.branchId == 'CH002' && !s.isChecking);
      old.complete(_json({'soLuongConTrong': 99}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.availableQuantity, 2);
      expect(bloc.state.priceQuote!['tongTienThue'], 200.25);
      expect(
        http.requests.where((r) => r.path == '/api/tam-tinh'),
        hasLength(1),
      );
    },
  );

  test(
    'unknown cancellation retains the hold until Backend confirms release',
    () async {
      final http = _Http((r) {
        if (r.method == 'POST') {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json(_hold());
      });
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CancelReservation());
      final result = await _until(bloc, (s) => s.reservationError != null);
      expect(result.maGiuCho, 'GC-OFFLINE');
      expect(http.requests.map((r) => r.method), ['POST', 'GET']);
    },
  );

  test(
    'expiry confirmed by GET clears hold identity and blocks rental',
    () async {
      final http = _Http((_) => _json(_hold(status: 'HET_HAN')));
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CheckReservationStatus());
      final result = await _until(bloc, (s) => s.isReservationExpired);
      expect(result.maGiuCho, isNull);
      expect(result.idempotencyKey, isNull);
      expect(result.initialTimeRemaining, isNull);
      expect(result.cartItems, isEmpty);
      expect(result.isValidToRent, isFalse);
    },
  );

  test(
    'contract timeout recovers its ID using GET, never a second POST',
    () async {
      final http = _Http((r) {
        if (r.method == 'POST') {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return _json(
          r.path.contains('theo-giu-cho')
              ? {'maHopDong': 'HDTEST'}
              : _hold(status: 'DA_CHUYEN_HOP_DONG'),
        );
      });
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CreateContract());
      final result = await _until(bloc, (s) => s.contractId != null);
      expect(result.contractId, 'HDTEST');
      expect(http.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test(
    'code-only CART_VERSION_CONFLICT is visible and blocks contract creation',
    () async {
      final http = _Http(
        (r) =>
            r.method == 'POST'
                ? _json({'code': 'CART_VERSION_CONFLICT'}, 409)
                : _json(_hold()),
      );
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CreateContract());
      final result = await _until(bloc, (s) => s.createContractError != null);
      expect(result.createContractError, contains('giỏ hàng'));
      expect(result.cartEditNeedsReconciliation, isTrue);
      expect(result.contractId, isNull);
    },
  );

  test(
    'late contract creation response cannot enter a different account session',
    () async {
      final entered = Completer<void>(), reply = Completer<ResponseBody>();
      final http = _Http((r) {
        entered.complete();
        return reply.future;
      });
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CreateContract());
      await entered.future.timeout(const Duration(seconds: 3));
      await TokenStorage.saveToken('offline-account-B');
      await _until(bloc, (s) => s.maGiuCho == null);
      reply.complete(_json({'maHopDong': 'HDTEST'}, 201));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.contractId, isNull);
    },
  );

  test(
    'payment preserves decimal amounts and rejects a different contract deposit',
    () async {
      final data = {
        'maThanhToan': 'TT1',
        'maHopDong': 'OTHER',
        'soTien': 100.25,
        'loaiThanhToan': 'TIEN_COC',
        'phuongThuc': 'TIEN_MAT',
        'trangThai': 'THANH_CONG',
      };
      expect(PaymentModel.fromJson(data).soTien, 100.25);
      final http = _Http((_) => _json(data));
      final bloc = PaymentBloc(repository: PaymentRepository(dio: http.dio));
      addTearDown(bloc.close);
      bloc.add(const CheckPaymentStatus('HDTEST', paymentId: 'TT1'));
      await bloc.stream
          .firstWhere((s) => s is PaymentError)
          .timeout(const Duration(seconds: 3));
      expect(bloc.state, isA<PaymentError>());
      expect(http.requests.single.method, 'GET');
    },
  );

  test(
    'late hold-to-contract lookup cannot reopen a different rental context',
    () async {
      final entered = Completer<void>(), reply = Completer<ResponseBody>();
      final http = _Http((r) {
        if (r.path.contains('theo-giu-cho')) {
          entered.complete();
          return reply.future;
        }
        return _json(_hold(status: 'DA_CHUYEN_HOP_DONG'));
      });
      final bloc = _Rental(http.dio)..seed(ready(held: true));
      addTearDown(bloc.close);
      bloc.add(const CheckReservationStatus());
      await entered.future.timeout(const Duration(seconds: 3));
      bloc.add(InitializeRental(device.copyWith(id: 'OTHER_MODEL')));
      await _until(bloc, (s) => s.selectedDevice?.id == 'OTHER_MODEL');
      reply.complete(_json({'maHopDong': 'OLD_CONTRACT'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.contractId, isNull);
    },
  );

  test(
    'invalid credentials are cleared even if optional session cleanup fails',
    () async {
      TokenStorage.beforeSessionChange =
          () async => throw StateError('Synthetic unlink failure');
      await expectLater(TokenStorage.deleteToken(), throwsStateError);
      expect(await TokenStorage.getToken(), isNull);
      expect(TokenStorage.isChanging, isFalse);
    },
  );

  testWidgets('confirmation waits for Backend cancellation before leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Cancellation();
    final http = _Http((_) => throw StateError('Unexpected request'));
    final bloc = _Rental(http.dio, repository: repository)
      ..seed(ready(held: true));
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/confirm',
      routes: [
        GoRoute(
          path: '/confirm',
          builder:
              (_, state) => BlocProvider<RentalBloc>.value(
                value: bloc,
                child: const RentalConfirmationView(),
              ),
        ),
        GoRoute(
          path: '/device/:id',
          builder: (_, state) => const Scaffold(body: Text('Đã quay lại')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy giữ chỗ'));
    for (
      var frame = 0;
      frame < 10 && !repository.entered.isCompleted;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      repository.entered.isCompleted,
      isTrue,
      reason:
          'checking=${bloc.state.isChecking}, expired=${bloc.state.isReservationExpired}, held=${bloc.state.maGiuCho}, error=${bloc.state.reservationError}',
    );
    expect(bloc.state.maGiuCho, 'GC-OFFLINE');
    expect(find.text('Đã quay lại'), findsNothing);
    repository.result.complete();
    for (var frame = 0; frame < 10 && bloc.state.maGiuCho != null; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Đã quay lại'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('401 invalidates only the token rejected by Backend', () async {
    final dio = ApiClient.instance,
        original = ApiClient.instance.httpClientAdapter;
    dio.httpClientAdapter = _Http((_) => _json({'loi': 'Hết phiên.'}, 401));
    addTearDown(() => dio.httpClientAdapter = original);
    await expectLater(dio.get('/api/gio-hang'), throwsA(isA<DioException>()));
    expect(await TokenStorage.getToken(), isNull);
  });

  test('late 401 does not remove the newly logged-in account', () async {
    final entered = Completer<void>(), reply = Completer<ResponseBody>();
    final dio = ApiClient.instance,
        original = ApiClient.instance.httpClientAdapter;
    dio.httpClientAdapter = _Http((_) {
      entered.complete();
      return reply.future;
    });
    addTearDown(() => dio.httpClientAdapter = original);
    final request = dio.get('/api/gio-hang');
    final expectation = expectLater(request, throwsA(isA<DioException>()));
    await entered.future.timeout(const Duration(seconds: 3));
    await TokenStorage.saveToken('offline-account-B');
    reply.complete(_json({}, 401));
    await expectation;
    expect(await TokenStorage.getToken(), 'offline-account-B');
  });

  testWidgets('result page displays the exact fractional amount from Backend', (
    tester,
  ) async {
    final http = _Http(
      (_) => _json({
        'maThanhToan': 'TT1',
        'maHopDong': 'HDTEST',
        'soTien': 100.25,
        'loaiThanhToan': 'TIEN_COC',
        'phuongThuc': 'TIEN_MAT',
        'trangThai': 'THANH_CONG',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentResultPage(
          paymentId: 'TT1',
          repository: PaymentRepository(dio: http.dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(const AppMoneyFormatter().format(100.25)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'missing Backend bank information never generates a fallback recipient QR',
    (tester) async {
      final http = _Http(
        (_) => _json([
          {
            'maThanhToan': 'TT1',
            'maHopDong': 'HDTEST',
            'soTien': 100.25,
            'loaiThanhToan': 'TIEN_COC',
            'phuongThuc': 'CHUYEN_KHOAN',
            'trangThai': 'CHO_THANH_TOAN',
          },
        ]),
      );
      final contract =
          ContractDetailData.fromJson(
            fixture(status: 'DA_KY'),
            'HDTEST',
          ).contract;
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentPage(
            contract: contract,
            repository: PaymentRepository(dio: http.dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Backend chưa cung cấp đủ thông tin chuyển khoản'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url.contains('img.vietqr.io'),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
