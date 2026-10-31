import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_document_repository.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/domain/models/contract_payment_summary.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_document_cubit.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/features/contract/presentation/widgets/contract_payment_card.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_page.dart';
import 'package:rentcam/features/contract/presentation/tracking/widgets/contract_status_steps.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'contract_handover_test.dart' show fixture;

Map<String, dynamic> _data([String status = 'CHO_BAN_GIAO']) =>
    fixture(status: status)
      ..['thanhToan'] = []
      ..['phuLuc'] = []
      ..['maBamTepPdf'] = 'test-only-stored-pdf-hash';

Map<String, dynamic> _receipt(
  String id,
  String status, {
  String type = 'TIEN_COC',
  num amount = 3000000,
}) => {
  'maThanhToan': id,
  'maHopDong': 'HDTEST',
  'loaiThanhToan': type,
  'trangThai': status,
  'soTien': amount,
  'phuongThuc': 'CHUYEN_KHOAN',
};

class _Repository extends ContractRepository {
  final Map<String, dynamic> data;
  _Repository(this.data);
  @override
  Future<Map<String, dynamic>> getContractById(String id) async => data;
  @override
  Future<List<int>> getHandoverImage(String url) async =>
      throw Exception('Image unavailable');
  @override
  Future<void> cancelContract(String id) => throw UnimplementedError();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'payment card shows actual successful rent separately from the deposit',
    (tester) async {
      final json =
          _data()
            ..['thanhToan'] = [
              _receipt('COC', 'THANH_CONG'),
              _receipt(
                'THUE',
                'THANH_CONG',
                type: 'TIEN_THUE',
                amount: 1000000,
              ),
              _receipt(
                'FEE',
                'CHO_THANH_TOAN',
                type: 'PHI_PHAT',
                amount: 90000,
              ),
            ];
      final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
      var openedPayments = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContractPaymentCard(
                contract: model,
                onViewPayments: () => openedPayments = true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Đã thanh toán cọc'), findsOneWidget);
      expect(find.text('Tiền thuê đã thanh toán'), findsOneWidget);
      expect(find.text('Phí phạt đã thanh toán'), findsNothing);
      expect(model.payments.depositPaid, 3000000);
      expect(model.payments.rentalRemaining, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('contract-view-payments')),
      );
      await tester.tap(find.byKey(const ValueKey('contract-view-payments')));
      expect(openedPayments, isTrue);
    },
  );

  test(
    'successful deposit is separate from rent and duplicate IDs/attempts are not added twice',
    () {
      final receipt = _receipt('TT1', 'THANH_CONG');
      final json =
          _data()
            ..['thanhToan'] = [
              receipt,
              {...receipt},
              _receipt('TT2', 'CHO_THANH_TOAN'),
              _receipt('TT3', 'THAT_BAI'),
            ]
            ..['yeuCauThanhToanVnpay'] = [
              {'trangThai': 'THANH_CONG', 'soTien': 3000000},
            ];
      final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
      expect(model.payments.depositPaid, 3000000);
      expect(model.payments.depositRemaining, 0);
      expect(model.payments.rentalRemaining, isNull);
      expect(model.payments.totalRemaining, isNull);
      expect(
        model.payments.successfulDeposits.single.methodLabel,
        'Chuyển khoản',
      );
      expect(
        model.copyWith(status: 'DANG_THUE').payments,
        same(model.payments),
      );
    },
  );

  test('pending/failed/cash requests never count as paid', () {
    final json =
        _data()
          ..['thanhToan'] = [
            _receipt('TT1', 'CHO_THANH_TOAN')..['phuongThuc'] = 'TIEN_MAT',
            _receipt('TT2', 'THAT_BAI'),
          ];
    final summary = ContractPaymentSummary.fromContractJson(json);
    expect(summary.depositPaid, 0);
    expect(summary.depositRemaining, 3000000);
    expect(summary.successfulDeposits, isEmpty);
  });

  test('missing/malformed/contradictory receipts keep balances unknown', () {
    for (final json in [
      _data()..remove('thanhToan'),
      _data()..['thanhToan'] = null,
      _data()
        ..['thanhToan'] = [_receipt('TT1', 'THANH_CONG')..remove('soTien')],
      _data()
        ..['thanhToan'] = [
          _receipt('TT1', 'THANH_CONG'),
          _receipt('TT1', 'THAT_BAI'),
        ],
      _data()
        ..['thanhToan'] = [
          _receipt('TT1', 'THANH_CONG')..['maHopDong'] = 'OTHER',
        ],
    ]) {
      final summary = ContractPaymentSummary.fromContractJson(json);
      expect(summary.depositPaid, isNull);
      expect(summary.depositRemaining, isNull);
      expect(summary.totalRemaining, isNull);
    }
  });

  for (final status in ['CHO_THANH_TOAN', 'DA_HOAN']) {
    test(
      'refund $status preserves the original successful receipt without inventing a balance',
      () {
        final json = _data('CHO_HOAN_TRA')
          ..['thanhToan'] = [
            _receipt('TT1', 'THANH_CONG'),
            _receipt('REFUND', status, type: 'HOAN_COC'),
          ];
        final summary = ContractPaymentSummary.fromContractJson(json);
        expect(summary.depositPaid, 3000000);
        expect(summary.depositRemaining, isNull);
        expect(summary.receipts.first.status, 'THANH_CONG');
        expect(summary.receipts.last.status, status);
      },
    );
  }

  test(
    'supplementary deposits and overpayments need confirmed balance data',
    () {
      final json =
          _data()
            ..['phuLuc'] = [
              {'tienCocBoSung': 1000000},
            ];
      expect(
        ContractPaymentSummary.fromContractJson(json).depositRemaining,
        isNull,
      );
      json['phuLuc'] = [];
      json['thanhToan'] = [_receipt('TT1', 'THANH_CONG', amount: 4000000)];
      expect(
        ContractPaymentSummary.fromContractJson(json).depositRemaining,
        isNull,
      );
    },
  );

  for (final status in [
    'DA_KY',
    'CHO_BAN_GIAO',
    'DANG_THUE',
    'CHO_HOAN_TRA',
    'HOAN_THANH',
    'DA_HUY',
  ]) {
    test(
      '$status loads the exact stored signed PDF using the contract ID',
      () async {
        final dio = Dio();
        addTearDown(dio.close);
        final bytes = ascii.encode('%PDF-1.7\nstored-document-for-HDTEST');
        var requests = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests++;
              expect(options.method, 'GET');
              expect(options.path, '/api/hop-dong/HDTEST/tep-pdf');
              expect(options.followRedirects, isFalse);
              handler.resolve(
                Response<List<int>>(
                  requestOptions: options,
                  data: bytes,
                  statusCode: 200,
                ),
              );
            },
          ),
        );
        final model =
            ContractDetailData.fromJson(_data(status), 'HDTEST').contract;
        final loaded = await ContractDocumentRepository(dio: dio).load(model);
        expect(loaded, bytes);
        expect(requests, 1);
      },
    );
  }

  test(
    'known missing signed PDF and server conflict never regenerate a substitute',
    () async {
      final dio = Dio();
      addTearDown(dio.close);
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: 409),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final repository = ContractDocumentRepository(dio: dio);
      final missing =
          ContractDetailData.fromJson(
            _data()..['maBamTepPdf'] = null,
            'HDTEST',
          ).contract;
      await expectLater(repository.load(missing), throwsA(isA<Exception>()));
      expect(requests, 0);
      final available = ContractDetailData.fromJson(_data(), 'HDTEST').contract;
      await expectLater(repository.load(available), throwsA(isA<Exception>()));
      expect(requests, 1);
    },
  );

  test('signed PDF endpoint returning HTML is rejected', () async {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<List<int>>(
              requestOptions: options,
              data: ascii.encode('<html>error</html>'),
              statusCode: 200,
            ),
          );
        },
      ),
    );
    final model = ContractDetailData.fromJson(_data(), 'HDTEST').contract;
    await expectLater(
      ContractDocumentRepository(dio: dio).load(model),
      throwsA(isA<Exception>()),
    );
  });

  test('PDF requests coalesce and completion after close is safe', () async {
    final dio = Dio();
    addTearDown(dio.close);
    final waiting = Completer<void>();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests++;
          await waiting.future;
          handler.resolve(
            Response<List<int>>(
              requestOptions: options,
              data: ascii.encode('%PDF-fixture'),
              statusCode: 200,
            ),
          );
        },
      ),
    );
    final cubit = ContractDocumentCubit(ContractDocumentRepository(dio: dio));
    final model = ContractDetailData.fromJson(_data(), 'HDTEST').contract;
    final first = cubit.load(model);
    final second = cubit.load(model);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    waiting.complete();
    await Future.wait([first, second]);
    expect(requests, 1);
  });

  for (final status in [
    'CHO_BAN_GIAO',
    'DANG_THUE',
    'CHO_HOAN_TRA',
    'HOAN_THANH',
  ]) {
    testWidgets(
      '$status primary action follows Backend and the existing destination',
      (tester) async {
        final repository = _Repository(_data(status));
        ContractModel? routed;
        String? destination;
        Widget destinationBuilder(BuildContext context, GoRouterState state) {
          routed = state.extra! as ContractModel;
          destination = state.uri.path;
          if (destination == '/contract/renewal') {
            return ContractRenewalPage(contract: routed!);
          }
          return const Scaffold(body: Text('Existing destination'));
        }

        final router = GoRouter(
          initialLocation: '/contract/HDTEST',
          routes: [
            GoRoute(path: '/payment', builder: destinationBuilder),
            GoRoute(path: '/contract/renewal', builder: destinationBuilder),
            GoRoute(path: '/contract/preview', builder: destinationBuilder),
            GoRoute(
              path: '/contract/:id',
              builder:
                  (context, state) => ContractPage(
                    contractId: 'HDTEST',
                    repository: repository,
                  ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        final actionFinder = find.byKey(
          const ValueKey('contract-primary-action'),
        );
        final button = tester.widget<ElevatedButton>(actionFinder);
        const labels = {
          'CHO_BAN_GIAO': 'Xem thanh toán',
          'DANG_THUE': 'Gia hạn thuê',
          'CHO_HOAN_TRA': 'Xem hợp đồng điện tử',
          'HOAN_THANH': 'Đánh giá',
        };
        expect(
          find.descendant(
            of: actionFinder,
            matching: find.text(labels[status]!),
          ),
          findsOneWidget,
        );
        if (status == 'HOAN_THANH') {
          expect(button.onPressed, isNotNull);
          await tester.tap(actionFinder);
          await tester.pumpAndSettle();
          expect(find.text('Chọn thiết bị để đánh giá'), findsOneWidget);
          expect(destination, isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(ContractPage), findsOneWidget);
        } else {
          await tester.tap(actionFinder);
          await tester.pumpAndSettle();
          expect(
            destination,
            {
              'CHO_BAN_GIAO': '/payment',
              'DANG_THUE': '/contract/renewal',
              'CHO_HOAN_TRA': '/contract/preview',
            }[status],
          );
          expect(routed!.contractId, 'HDTEST');
          expect(routed!.assignedDevices.length, 3);
          if (status == 'DANG_THUE') {
            expect(find.byType(ContractRenewalPage), findsOneWidget);
          }
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(ContractPage), findsOneWidget);
          if (status == 'DANG_THUE') {
            final payments = find.byKey(
              const ValueKey('contract-view-payments'),
            );
            await tester.ensureVisible(payments);
            await tester.tap(payments);
            await tester.pumpAndSettle();
            expect(destination, '/payment');
            expect(routed!.contractId, 'HDTEST');
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(ContractPage), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final status in ['CHO_HOAN_TRA', 'HOAN_THANH', 'DA_HUY', 'UNKNOWN']) {
    testWidgets(
      '$status keeps all device details readable at 320px and 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final json = _data(status)
          ..['thanhToan'] = [_receipt('TT1', 'THANH_CONG')];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    padding: const EdgeInsets.only(bottom: 34),
                  ),
                  child: child!,
                ),
            home: ContractPage(
              contractId: 'HDTEST',
              repository: _Repository(json),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Serial: SERIAL1'), findsOneWidget);
        expect(find.text('Serial: SERIAL2'), findsOneWidget);
        expect(find.text('Serial: SERIAL3'), findsOneWidget);
        expect(find.text('Đã thanh toán cọc'), findsOneWidget);
        expect(find.textContaining('Chuyển khoản'), findsOneWidget);
        final scrollable =
            find
                .descendant(
                  of: find.byKey(
                    const PageStorageKey('contract-detail-scroll'),
                  ),
                  matching: find.byType(Scrollable),
                )
                .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        for (
          double offset = 0;
          offset < position.maxScrollExtent;
          offset += 200
        ) {
          position.jumpTo(offset);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        final chips = tester.widget<ContractStatusSteps>(
          find.byType(ContractStatusSteps),
        );
        if (status == 'UNKNOWN') expect(chips.status.name, 'unknown');
        if (status == 'DA_HUY' || status == 'UNKNOWN') {
          final stepSemantics = tester.widgetList<Semantics>(
            find.descendant(
              of: find.byType(ContractStatusSteps),
              matching: find.byType(Semantics),
            ),
          );
          expect(
            stepSemantics.where((s) => s.properties.selected == true),
            status == 'DA_HUY' ? hasLength(1) : isEmpty,
          );
          expect(
            find.byKey(const ValueKey('contract-primary-action')),
            findsNothing,
          );
        } else {
          expect(
            tester
                .getBottomRight(
                  find.byKey(const ValueKey('contract-primary-action')),
                )
                .dy,
            lessThanOrEqualTo(640 - 34 - 12),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('known missing signed file disables signed document actions', (
    tester,
  ) async {
    final json = _data('CHO_HOAN_TRA')..['maBamTepPdf'] = null;
    await tester.pumpWidget(
      MaterialApp(
        home: ContractPage(contractId: 'HDTEST', repository: _Repository(json)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('contract-primary-action')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('contract-preview')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('contract-download-pdf')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Chưa có bản hợp đồng đã ký'), findsWidgets);
  });
}
