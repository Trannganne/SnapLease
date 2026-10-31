import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import 'package:rentcam/core/widgets/retro_camera_loader.dart';
import 'package:rentcam/core/widgets/reservation_timer.dart';
import 'package:rentcam/data/mock/mock_device_detail_repository.dart';
import 'package:rentcam/domain/entities/device_detail.dart';
import 'package:rentcam/features/auth/data/auth_repository.dart';
import 'package:rentcam/features/auth/login/bloc/login_bloc.dart';
import 'package:rentcam/features/auth/login/bloc/login_state.dart';
import 'package:rentcam/features/auth/login/presentation/login_page.dart';
import 'package:rentcam/features/auth/register/bloc/register_bloc.dart';
import 'package:rentcam/features/auth/register/bloc/register_state.dart';
import 'package:rentcam/features/auth/register/presentation/register_page.dart';
import 'package:rentcam/features/identity_verification/bloc/identity_verification_bloc.dart';
import 'package:rentcam/features/identity_verification/bloc/identity_verification_state.dart';
import 'package:rentcam/features/identity_verification/presentation/identity_verification_page.dart';
import 'package:rentcam/features/identity_verification/presentation/widgets/verification_result_review.dart';
import 'package:rentcam/features/identity_verification/services/identity_scanner.dart';
import 'package:rentcam/features/rental/bloc/rental_bloc.dart';
import 'package:rentcam/features/rental_confirmation/presentation/rental_confirmation_page.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_document_repository.dart';
import 'package:rentcam/features/contract/data/repositories/dio_contract_signing_repository.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_signing_cubit.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_signing_state.dart';
import 'package:rentcam/features/contract/presentation/signature_page.dart';
import 'package:rentcam/features/contract/presentation/widgets/otp_verification_dialog.dart';
import 'package:rentcam/features/contract/presentation/contract_preview_page.dart';
import 'package:rentcam/features/payment/presentation/payment_page.dart';
import 'package:rentcam/features/payment/presentation/payment_result_page.dart';
import 'package:rentcam/features/payment/bloc/payment_bloc.dart';
import 'package:rentcam/features/device_detail/bloc/device_detail_bloc.dart';
import 'package:rentcam/features/device_detail/bloc/device_detail_state.dart';
import 'package:rentcam/features/device_detail/data/device_detail_repository.dart';
import 'package:rentcam/features/device_detail/presentation/device_detail_page.dart';
import 'package:rentcam/features/cart/bloc/cart_bloc.dart';
import 'package:rentcam/features/cart/data/repositories/mock_cart_repository.dart';
import 'contract_handover_test.dart' show fixture;

class _Login extends LoginBloc {
  _Login() : super(authRepository: AuthRepository());
  void show(LoginState state) => emit(state);
}

class _Device extends DeviceDetailBloc {
  _Device(DeviceDetail device) : super(repository: DeviceDetailRepository()) {
    emit(DeviceDetailState(status: DeviceDetailStatus.loaded, detail: device));
  }
}

class _Register extends RegisterBloc {
  _Register() : super(authRepository: AuthRepository());
  void show(RegisterState state) => emit(state);
}

class _Identity extends IdentityVerificationBloc {
  void show(IdentityVerificationState state) => emit(state);
}

class _Clock extends Stopwatch {
  Duration time = Duration.zero;
  @override
  Duration get elapsed => time;
}

class _Rental extends RentalBloc {
  final clock = _Clock();
  final events = <RentalEvent>[];
  @override
  Stopwatch get reservationStopwatch => clock;
  void show(RentalState state) => emit(state);
  @override
  void add(RentalEvent event) {
    events.add(
      event,
    ); // Presentation fixture: never dispatch a real API request.
    if (event is CheckReservationStatus) {
      show(state.copyWith(isReservationExpired: true));
    }
  }
}

class _Signing extends ContractSigningCubit {
  _Signing() : super(DioContractSigningRepository());
  void show(ContractSigningState state) => emit(state);
}

class _Documents extends ContractDocumentRepository {
  final result = Completer<Uint8List>();
  @override
  Future<Uint8List> load(ContractModel contract) => result.future;
}

class _Http implements HttpClientAdapter {
  final Future<dynamic> Function(RequestOptions) handle;
  final calls = <RequestOptions>[];
  _Http(this.handle);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    final data = await handle(options);
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Widget app(Widget child) =>
    MaterialApp(theme: AppTheme.lightTheme, home: child);
void camera(WidgetTester tester) {
  expect(find.byType(SnapLoadingView), findsOneWidget);
  expect(
    tester.widget<SnapLoadingView>(find.byType(SnapLoadingView)).size,
    RetroCameraLoader.large,
  );
  expect(find.byType(SnapButtonLoader), findsNothing);
}

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Map<String, dynamic> bankPayment() => {
  'maThanhToan': 'PAY-FIXTURE',
  'maHopDong': 'HDTEST',
  'soTien': 500000,
  'loaiThanhToan': 'TIEN_COC',
  'phuongThuc': 'CHUYEN_KHOAN',
  'trangThai': 'CHO_THANH_TOAN',
  'nhaCungCap': 'BIDV',
  'soTaiKhoan': '0000000000',
  'chuTaiKhoan': 'TEST FIXTURE',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DeviceDetail device;
  late ContractModel contract;
  setUpAll(() async {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    );
    final fonts = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      fonts.addFont(
        File.fromUri(
          Uri.parse(
            '${config['flutterRoot']}/bin/cache/artifacts/material_fonts/$name',
          ),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await fonts.load();
    await initializeDateFormatting('vi_VN');
    device = await MockDeviceDetailRepository().getDeviceDetail('DM1');
    contract =
        ContractDetailData.fromJson(
          fixture(status: 'CHO_BAN_GIAO'),
          'HDTEST',
        ).contract;
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'google_mlkit_text_recognizer',
      'google_mlkit_barcode_scanning',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
  });

  testWidgets(
    'Login overlay keeps credentials on failure and disappears on route/success',
    (tester) async {
      final bloc = _Login();
      addTearDown(bloc.close);
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder:
                (_, _) => BlocProvider<LoginBloc>.value(
                  value: bloc,
                  child: const LoginView(),
                ),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home fixture')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await frames(tester);
      await tester.enterText(find.byType(TextField).first, 'user');
      await tester.enterText(find.byType(TextField).last, 'synthetic-password');
      await frames(tester);
      bloc.show(const LoginState(status: LoginStatus.loading));
      await frames(tester);
      camera(tester);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
        isTrue,
      );
      bloc.show(
        const LoginState(
          status: LoginStatus.failure,
          passwordError: 'Lỗi thử nghiệm',
        ),
      );
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'user',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'synthetic-password',
      );
      bloc.show(const LoginState(status: LoginStatus.loading));
      await frames(tester);
      bloc.show(const LoginState(status: LoginStatus.success));
      await frames(tester);
      final transition =
          ModalRoute.of(
            tester.element(find.text('Home fixture')),
          )!.transitionDuration;
      await tester.pump(transition);
      await tester.pump();
      expect(find.byType(LoginView), findsNothing);
      bloc.show(const LoginState(status: LoginStatus.loading));
      await frames(tester);
      expect(find.text('Home fixture'), findsOneWidget);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Register overlay keeps form and consent when request fails', (
    tester,
  ) async {
    final bloc = _Register();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      app(
        BlocProvider<RegisterBloc>.value(
          value: bloc,
          child: const RegisterView(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'draft-user');
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged!(true);
    await frames(tester);
    bloc.show(const RegisterState(status: RegisterStatus.loading));
    await frames(tester);
    camera(tester);
    bloc.show(
      const RegisterState(
        status: RegisterStatus.failure,
        usernameError: 'Lỗi thử nghiệm',
      ),
    );
    await frames(tester);
    expect(find.byType(SnapLoadingView), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'draft-user',
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Identity processing and confirming have one overlay, preserving extracted data on error',
    (tester) async {
      final bloc = _Identity();
      final rental = _Rental();
      addTearDown(bloc.close);
      addTearDown(rental.close);
      await tester.pumpWidget(
        app(
          MultiBlocProvider(
            providers: [
              BlocProvider<IdentityVerificationBloc>.value(value: bloc),
              BlocProvider<RentalBloc>.value(value: rental),
            ],
            child: const IdentityVerificationView(),
          ),
        ),
      );
      bloc.show(
        const IdentityVerificationState(
          status: IdentityVerificationStatus.loading,
          isConsentAccepted: true,
        ),
      );
      await frames(tester);
      camera(tester);
      final data = ExtractedIdentityData();
      bloc.show(
        IdentityVerificationState(
          status: IdentityVerificationStatus.confirming,
          extractedData: data,
          isConsentAccepted: true,
        ),
      );
      await frames(tester);
      camera(tester);
      bloc.show(
        IdentityVerificationState(
          status: IdentityVerificationStatus.confirmError,
          extractedData: data,
          isConsentAccepted: true,
          errorMessage: 'Không thể xác nhận',
        ),
      );
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        identical(
          tester
              .widget<VerificationResultReview>(
                find.byType(VerificationResultReview),
              )
              .data,
          data,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Reservation expires during identity overlay once; late success cannot reopen route',
    (tester) async {
      final bloc = _Identity();
      final rental = _Rental();
      rental.show(
        const RentalState(
          maGiuCho: 'HOLD-FIXTURE',
          initialTimeRemaining: Duration(seconds: 2),
        ),
      );
      bloc.show(
        const IdentityVerificationState(
          status: IdentityVerificationStatus.loading,
        ),
      );
      addTearDown(bloc.close);
      addTearDown(rental.close);
      final router = GoRouter(
        initialLocation: '/identity',
        routes: [
          GoRoute(
            path: '/identity',
            builder:
                (_, _) => MultiBlocProvider(
                  providers: [
                    BlocProvider<IdentityVerificationBloc>.value(value: bloc),
                    BlocProvider<RentalBloc>.value(value: rental),
                  ],
                  child: const IdentityVerificationView(),
                ),
          ),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Expired fixture')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await frames(tester);
      camera(tester);
      expect(find.byType(ReservationTimer), findsOneWidget);
      rental.clock.time = const Duration(seconds: 3);
      await tester.pump(const Duration(seconds: 1));
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(rental.events.whereType<CheckReservationStatus>(), hasLength(1));
      expect(router.routeInformationProvider.value.uri.path, '/');
      bloc.show(
        const IdentityVerificationState(
          status: IdentityVerificationStatus.verificationSuccess,
        ),
      );
      await frames(tester);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Reservation submit keeps device and rental selection after failure',
    (tester) async {
      final detail = _Device(device);
      final rental = _Rental();
      final cart = CartBloc(repository: MockCartRepository());
      addTearDown(detail.close);
      addTearDown(rental.close);
      addTearDown(cart.close);
      final selected = RentalState(
        selectedDevice: device,
        pickupDate: DateTime(2026, 11, 1),
        returnDate: DateTime(2026, 11, 3),
        branchId: device.branches.first.branchId,
        availableQuantity: 3,
      );
      rental.show(selected);
      await tester.pumpWidget(
        app(
          MultiBlocProvider(
            providers: [
              BlocProvider<DeviceDetailBloc>.value(value: detail),
              BlocProvider<RentalBloc>.value(value: rental),
              BlocProvider<CartBloc>.value(value: cart),
            ],
            child: const DeviceDetailView(),
          ),
        ),
      );
      await frames(tester);
      final scroll = find.byType(SingleChildScrollView).first.evaluate().single;
      rental.show(selected.copyWith(isCreatingReservation: true));
      await frames(tester);
      camera(tester);
      rental.show(selected.copyWith(reservationError: 'Không thể giữ chỗ'));
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        identical(
          find.byType(SingleChildScrollView).first.evaluate().single,
          scroll,
        ),
        isTrue,
      );
      expect(rental.state.pickupDate, selected.pickupDate);
      expect(rental.state.branchId, selected.branchId);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Creating contract blocks only form, timer survives, error retains rental data',
    (tester) async {
      final rental = _Rental();
      addTearDown(rental.close);
      final initial = RentalState(
        selectedDevice: device,
        pickupDate: DateTime(2026, 11, 1),
        returnDate: DateTime(2026, 11, 3),
        branchId: device.branches.first.branchId,
        isConfirmed: true,
        maGiuCho: 'HOLD-FIXTURE',
        initialTimeRemaining: const Duration(minutes: 3),
      );
      final quoted = initial.copyWith(
        priceQuote: {
          'soNgayTinhPhi': 2,
          'giaThueNgay': 450000,
          'tongTienThue': 900000,
          'phanTramGiamGia': 0,
          'tongTienCoc': 500000,
        },
        availableQuantity: 3,
      );
      rental.show(quoted);
      await tester.pumpWidget(
        app(
          BlocProvider<RentalBloc>.value(
            value: rental,
            child: const RentalConfirmationPage(),
          ),
        ),
      );
      await frames(tester);
      rental.show(quoted.copyWith(isCreatingContract: true));
      await frames(tester);
      camera(tester);
      expect(find.byType(ReservationTimer), findsOneWidget);
      rental.show(
        quoted.copyWith(
          isCreatingContract: false,
          createContractError: 'Không thể tạo hợp đồng',
        ),
      );
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(rental.state.isConfirmed, isTrue);
      expect(rental.state.maGiuCho, 'HOLD-FIXTURE');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Signing overlay preserves signature controller and consent on failure',
    (tester) async {
      final bloc = _Signing();
      addTearDown(bloc.close);
      await tester.pumpWidget(
        app(
          BlocProvider<ContractSigningCubit>.value(
            value: bloc,
            child: SignaturePage(contract: contract),
          ),
        ),
      );
      final before =
          tester.widget<Signature>(find.byType(Signature)).controller;
      before.addPoint(Point(const Offset(20, 20), PointType.tap, 1));
      before.addPoint(Point(const Offset(80, 60), PointType.move, 1));
      for (final checkbox in tester.widgetList<Checkbox>(
        find.byType(Checkbox),
      )) {
        checkbox.onChanged!(true);
      }
      await frames(tester);
      bloc.show(ContractSigningLoading());
      await frames(tester);
      camera(tester);
      bloc.show(const ContractSigningFailure('Không thể gửi ký'));
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        identical(
          tester.widget<Signature>(find.byType(Signature)).controller,
          before,
        ),
        isTrue,
      );
      expect(before.points, hasLength(2));
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((box) => box.value == true),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'OTP overlay is unique, failure keeps input, existing close works while processing',
    (tester) async {
      final bloc = _Signing();
      addTearDown(bloc.close);
      final expiry = DateTime.now().add(const Duration(minutes: 2));
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (_) => BlocProvider<ContractSigningCubit>.value(
                                value: bloc,
                                child: OtpVerificationDialog(
                                  contract: contract,
                                  maXacNhan: 'OTP-FIXTURE',
                                  emailMask: 't***@test.invalid',
                                  expiredAt: expiry,
                                  daDongYDieuKhoan: true,
                                ),
                              ),
                        ),
                    child: const Text('Open OTP'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open OTP'));
      await frames(tester);
      await tester.enterText(find.byType(TextField), '123456');
      bloc.show(
        ContractSigningOtpVerifying(
          maXacNhan: 'OTP-FIXTURE',
          emailMask: 't***@test.invalid',
          expiredAt: expiry,
        ),
      );
      await frames(tester);
      camera(tester);
      bloc.show(const ContractSigningFailure('OTP không hợp lệ'));
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '123456',
      );
      bloc.show(
        ContractSigningOtpVerifying(
          maXacNhan: 'OTP-FIXTURE',
          emailMask: 't***@test.invalid',
          expiredAt: expiry,
        ),
      );
      await frames(tester);
      await tester.tap(find.text('Đóng lại (để kiểm tra sau)').last);
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 400));
      bloc.show(const ContractSigningFailure('Late fixture'));
      await frames(tester);
      expect(find.byType(OtpVerificationDialog), findsNothing);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Payment background reads keep QR/scroll; explicit check alone uses overlay',
    (tester) async {
      final dio = ApiClient.instance;
      final original = dio.httpClientAdapter;
      var response = Completer<dynamic>();
      final adapter = _Http((_) => response.future);
      dio.httpClientAdapter = adapter;
      addTearDown(() {
        dio.httpClientAdapter = original;
      });
      await tester.pumpWidget(app(PaymentPage(contract: contract)));
      await frames(tester);
      camera(tester);
      response.complete([bankPayment()]);
      await frames(tester);
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      final qr = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url.contains('vietqr.io'),
      );
      expect(qr, findsOneWidget);
      final qrElement = qr.evaluate().single;
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, -120));
      await frames(tester);
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final offset = position.pixels;
      response = Completer<dynamic>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(find.byType(SnapLoadingProgress), findsOneWidget);
      expect(identical(qr.evaluate().single, qrElement), isTrue);
      expect(position.pixels, offset);
      response.complete([bankPayment()]);
      await frames(tester);
      response = Completer<dynamic>();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(identical(qr.evaluate().single, qrElement), isTrue);
      response.complete(bankPayment());
      await frames(tester);
      response = Completer<dynamic>();
      await tester.tap(find.text('Kiểm tra trạng thái'));
      await frames(tester);
      camera(tester);
      response.completeError(Exception('Read fixture failure'));
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(qr, findsOneWidget);
      expect(adapter.calls.every((request) => request.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Create payment shows one overlay, disables submit, releases on server error',
    (tester) async {
      final dio = ApiClient.instance;
      final original = dio.httpClientAdapter;
      final response = Completer<dynamic>();
      final adapter = _Http((request) {
        if (request.method == 'GET') return Future<dynamic>.value([]);
        return response.future;
      });
      dio.httpClientAdapter = adapter;
      addTearDown(() {
        dio.httpClientAdapter = original;
      });
      await tester.pumpWidget(app(PaymentPage(contract: contract)));
      await frames(tester);
      await frames(tester);
      final submit = find.byType(PrimaryButton).last;
      expect(tester.widget<PrimaryButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await frames(tester);
      await frames(tester);
      expect(
        tester.element(submit).read<PaymentBloc>().state.runtimeType.toString(),
        'PaymentCreating',
        reason:
            '${tester.element(submit).read<PaymentBloc>().state} ${adapter.calls.map((request) => '${request.method} ${request.path}').join(', ')}',
      );
      camera(tester);
      expect(tester.widget<PrimaryButton>(submit).isLoading, isTrue);
      expect(
        adapter.calls.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      final request = adapter.calls.last;
      response.completeError(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: request, statusCode: 422),
          message: 'Rejected fixture',
        ),
      );
      await frames(tester);
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        adapter.calls.where((request) => request.method == 'POST'),
        hasLength(1),
      );
      expect(find.byType(PaymentPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Payment result initial load and explicit retry never infer success on error',
    (tester) async {
      final dio = ApiClient.instance;
      final original = dio.httpClientAdapter;
      var response = Completer<dynamic>();
      final adapter = _Http((_) => response.future);
      dio.httpClientAdapter = adapter;
      addTearDown(() {
        dio.httpClientAdapter = original;
      });
      await tester.pumpWidget(
        app(const PaymentResultPage(paymentId: 'PAY-FIXTURE')),
      );
      await frames(tester);
      camera(tester);
      response.complete(bankPayment());
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      response = Completer<dynamic>();
      await tester.tap(find.text('Kiểm tra lại'));
      await frames(tester);
      camera(tester);
      response.completeError(Exception('Read fixture failure'));
      await frames(tester);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(
        find.textContaining('Chưa xác định trạng thái giao dịch'),
        findsOneWidget,
      );
      expect(adapter.calls.every((request) => request.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'PDF preview supplies camera loadingWidget and releases it on failure',
    (tester) async {
      const channel = MethodChannel('net.nfet.printing');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => {'canRaster': true},
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final documents = _Documents();
      await tester.pumpWidget(
        app(
          ContractPreviewPage(
            contract: contract,
            documentRepository: documents,
          ),
        ),
      );
      await frames(tester);
      expect(
        tester.widget<PdfPreview>(find.byType(PdfPreview)).loadingWidget,
        isA<SnapLoadingView>(),
      );
      // PdfPreviewRaster schedules work after its documented 300ms update timer.
      await tester.pump(const Duration(milliseconds: 300));
      final error = Exception('PDF không khả dụng');
      documents.result.completeError(error);
      await frames(tester);
      // printing reports the same build error while also showing its onError UI.
      expect(tester.takeException(), same(error));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('PDF không khả dụng'), findsOneWidget);
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
