import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/main.dart' as application;
import 'package:rentcam/app/router/app_router.dart';
import 'package:rentcam/features/main/presentation/main_layout.dart';
import 'package:rentcam/features/device_detail/presentation/device_detail_page.dart';
import 'package:rentcam/features/cart/presentation/cart_page.dart';
import 'package:rentcam/features/cart/bloc/cart_bloc.dart';
import 'package:rentcam/features/cart/data/repositories/mock_cart_repository.dart';
import 'package:rentcam/features/cart/domain/models/cart_item_model.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/widgets/retro_camera_loader.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/features/review/presentation/review_page.dart';
import 'package:rentcam/features/review/domain/models/review_form.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_page.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/domain/models/extension_models.dart';
import 'review_api_integration_test.dart' show ReviewServer, apiReview;
import 'contract_renewal_test.dart' show RenewalRepository;

class _HeldReads implements HttpClientAdapter {
  final methods = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    methods.add(options.method);
    if (options.method != 'GET') {
      throw StateError('No writes allowed in bootstrap test');
    }
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

class _HeldCart extends MockCartRepository {
  final result = Completer<List<CartItemModel>>();
  @override
  Future<List<CartItemModel>> getCartItems({bool forceRefresh = false}) =>
      result.future;
}

class _HeldRenewal extends RenewalRepository {
  final result = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> getContractById(String id) => result.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the SDK's real Roboto metrics when exercising full production pages.
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final directory = Uri.parse(
      '${config['flutterRoot']}/bin/cache/artifacts/material_fonts/',
    );
    final fonts = FontLoader('Roboto');
    for (final name in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
      fonts.addFont(
        File.fromUri(
          directory.resolve(name),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await fonts.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Real main.dart and production routes show large cameras before data',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'synthetic-bootstrap-session',
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dio = ApiClient.instance;
      final original = dio.httpClientAdapter;
      final held = _HeldReads();
      dio.httpClientAdapter = held;
      addTearDown(() {
        dio.httpClientAdapter = original;
      });
      await tester.runAsync(() async {
        application.main();
        await Future<void>.value();
      });
      await tester.pump();
      final routes = <String, String>{
        '/?tab=0': 'Đang tải thiết bị cho bạn',
        '/?tab=1': 'Đang tìm thiết bị phù hợp',
        '/?tab=2': 'Đang tải hợp đồng thuê',
        '/?tab=3': 'Đang tải thông báo',
        '/device/DM1': 'Đang tải chi tiết thiết bị',
        '/contract/HD1': 'Đang tải hợp đồng thuê',
        '/review/CT1': 'Đang tải thông tin đánh giá',
      };
      for (final route in routes.entries) {
        AppRouter.router.go('/test-api');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        AppRouter.router.go(route.key);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final loader = find.byWidgetPredicate(
          (widget) =>
              widget is SnapLoadingView &&
              widget.message == route.value &&
              widget.size == RetroCameraLoader.large,
        );
        expect(loader, findsOneWidget, reason: route.key);
        if (route.key.startsWith('/?')) {
          expect(
            find.descendant(
              of: find.ancestor(of: loader, matching: find.byType(MainLayout)),
              matching: find.byType(BottomNavigationBar),
            ),
            findsOneWidget,
          );
        }
        if (route.key.startsWith('/device/')) {
          expect(
            find.descendant(
              of: find.ancestor(
                of: loader,
                matching: find.byType(DeviceDetailView),
              ),
              matching: find.byType(AppBar),
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull, reason: route.key);
      }
      expect(held.methods, isNotEmpty);
      expect(held.methods.every((method) => method == 'GET'), isTrue);
      AppRouter.router.go('/test-api');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Cart initial camera is removed when data arrives, AppBar stays',
    (tester) async {
      final repository = _HeldCart();
      final bloc = CartBloc(repository: repository);
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<CartBloc>.value(
            value: bloc,
            child: const CartPage(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SnapLoadingView), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      repository.result.complete([]);
      await tester.pump();
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final timeout in [false, true]) {
    testWidgets(
      'Review overlay retains draft, disables button and releases after ${timeout ? 'uncertain timeout' : 'success'}',
      (tester) async {
        final server = ReviewServer()..postWait = Completer();
        await tester.pumpWidget(
          MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
        await tester.enterText(find.byType(TextField).first, 'Bản nháp');
        await tester.pump();
        await tester.tap(find.text('Gửi đánh giá'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(SnapLoadingView), findsOneWidget);
        expect(find.byType(SnapButtonLoader), findsNothing);
        expect(find.byType(ReviewPage), findsOneWidget);
        final button = tester.widget<PrimaryButton>(
          find.byType(PrimaryButton).first,
        );
        expect(button.isLoading, isTrue);
        final elevated = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.byType(PrimaryButton).first,
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(elevated.onPressed, isNull);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'Bản nháp',
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(ReviewPage), findsOneWidget);
        expect(server.posts, 1);
        if (timeout) {
          server.readError = const ReviewFailure('Mất kết nối khi đối soát');
          server.postWait!.completeError(
            ReviewFailure('Chưa xác định', uncertain: true),
          );
        } else {
          server.stored = apiReview();
          server.postWait!.complete(server.stored!);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SnapLoadingView), findsNothing);
        expect(server.posts, 1);
        if (timeout) {
          expect(find.text('Đối soát đánh giá'), findsOneWidget);
          expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .controller!
                .text,
            'Bản nháp',
          );
          expect(find.text('Đã gửi đánh giá'), findsNothing);
        } else {
          expect(find.text('Đã gửi đánh giá'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Renewal first load keeps AppBar and Back available', (
    tester,
  ) async {
    await initializeDateFormatting('vi_VN');
    final repository = _HeldRenewal();
    final contract =
        ContractDetailData.fromJson(repository.json, 'HDTEST').contract;
    await tester.pumpWidget(
      MaterialApp(
        home: ContractRenewalPage(contract: contract, repository: repository),
      ),
    );
    await tester.pump();
    expect(find.byType(SnapLoadingView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnapLoadingOverlay),
        matching: find.byType(ModalBarrier),
      ),
      findsNothing,
    );
    final back = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_back),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNotNull);
    repository.result.complete(repository.json);
    await tester.pump();
    expect(find.byType(SnapLoadingView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final timeout in [false, true]) {
    testWidgets(
      'Renewal overlay retains reason and ends after ${timeout ? 'uncertain timeout' : 'success'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await initializeDateFormatting('vi_VN');
        final repository = RenewalRepository();
        final contract =
            ContractDetailData.fromJson(repository.json, 'HDTEST').contract;
        await tester.pumpWidget(
          MaterialApp(
            home: ContractRenewalPage(
              contract: contract,
              repository: repository,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.ensureVisible(find.text('+3 ngày'));
        await tester.tap(find.text('+3 ngày'));
        await tester.pump();
        expect(repository.previews, hasLength(1));
        repository.previews.single.complete(repository.quote(0));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Cần thêm thời gian');
        await tester.pump();
        await tester.tap(find.text('Gửi yêu cầu'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byType(SnapLoadingView), findsOneWidget);
        expect(find.byType(SnapButtonLoader), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Cần thêm thời gian',
        );
        expect(
          tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
          isTrue,
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(ContractRenewalPage), findsOneWidget);
        expect(repository.posts, 1);
        if (timeout) {
          repository.post!.completeError(
            const ExtensionFailure('Chưa xác định', uncertain: true),
          );
        } else {
          repository.json['phuLuc'] = [
            repository.supplement(repository.dates.single),
          ];
          repository.post!.complete({});
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SnapLoadingView), findsNothing);
        expect(repository.posts, 1);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Cần thêm thời gian',
        );
        if (timeout) {
          expect(find.textContaining('Đã gửi yêu cầu gia hạn'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
