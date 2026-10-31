import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'package:rentcam/features/payment/bloc/payment_bloc.dart';
import 'package:rentcam/features/payment/bloc/payment_event.dart';
import 'package:rentcam/features/payment/bloc/payment_state.dart';
import 'package:rentcam/features/payment/data/payment_repository.dart';
import 'package:rentcam/features/payment/domain/enums/payment_method.dart';
import 'package:rentcam/features/payment/domain/models/payment_model.dart';
import 'package:rentcam/features/payment/presentation/payment_page.dart';

import 'payment_feature_test.dart' show FakePaymentRepository;

PaymentModel receipt({
  String status = 'CHO_THANH_TOAN',
  String method = 'TIEN_MAT',
  String contractId = 'CASH_CONTRACT',
  String type = 'TIEN_COC',
}) => PaymentModel(
  maThanhToan: 'CASH_RECEIPT',
  maHopDong: contractId,
  soTien: 250000,
  loaiThanhToan: type,
  phuongThuc: method,
  trangThai: status,
);

Future<List<PaymentState>> runEvent(
  FakePaymentRepository repository,
  PaymentEvent event,
  bool Function(PaymentState) finished,
) async {
  final bloc = PaymentBloc(repository: repository);
  final states = <PaymentState>[];
  final subscription = bloc.stream.listen(states.add);
  final result = bloc.stream.firstWhere(finished);
  bloc.add(event);
  try {
    await result.timeout(const Duration(seconds: 2));
    return states;
  } finally {
    await bloc.close();
    await subscription.cancel();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Match the existing screen-loading harness. The inherited asset .ttf files
    // contain HTML, so they cannot replace the widget test's Ahem font.
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
  });
  test(
    'cash request sends method only and accepts the server amount',
    () async {
      final dio = Dio();
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'maThanhToan': 'CASH_RECEIPT',
                  'maHopDong': 'CASH_CONTRACT',
                  'soTien': 250000,
                  'loaiThanhToan': 'TIEN_COC',
                  'phuongThuc': 'TIEN_MAT',
                  'trangThai': 'CHO_THANH_TOAN',
                },
              ),
            );
          },
        ),
      );
      final payment = await PaymentRepository(
        dio: dio,
      ).createDepositPayment('CASH_CONTRACT', 'TIEN_MAT');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(
        requests.single.path,
        '/api/hop-dong/CASH_CONTRACT/thanh-toan-coc',
      );
      expect(requests.single.data, {
        'phuongThuc': 'TIEN_MAT',
        'noiDungChuyenKhoan': '',
      });
      expect(payment.soTien, 250000);
      expect(payment.trangThai, 'CHO_THANH_TOAN');
      dio.close();
    },
  );

  test(
    'choosing cash creates a pending receipt, never a paid receipt',
    () async {
      final repo = FakePaymentRepository()..createdPaymentToReturn = receipt();
      final states = await runEvent(
        repo,
        const CreatePaymentRequested(
          'CASH_CONTRACT',
          PaymentMethod.cashOnHandover,
        ),
        (state) => state is PaymentCreatePending,
      );
      expect(repo.createCallCount, 1);
      expect(repo.createVnpayUrlCallCount, 0);
      expect(repo.reconcileCallCount, 0);
      expect(states.whereType<PaymentCreateSuccess>(), isEmpty);
    },
  );

  test('existing cash request is reused without another collection', () async {
    final repo = FakePaymentRepository()..paymentsToReturn = [receipt()];
    await runEvent(
      repo,
      const CreatePaymentRequested(
        'CASH_CONTRACT',
        PaymentMethod.cashOnHandover,
      ),
      (state) => state is PaymentCreatePending,
    );
    expect(repo.createCallCount, 0);
    expect(repo.createVnpayUrlCallCount, 0);
  });

  test('a pending other method cannot be replaced with cash', () async {
    final repo =
        FakePaymentRepository()
          ..paymentsToReturn = [receipt(method: 'VI_DIEN_TU')];
    await runEvent(
      repo,
      const CreatePaymentRequested(
        'CASH_CONTRACT',
        PaymentMethod.cashOnHandover,
      ),
      (state) => state is PaymentError,
    );
    expect(repo.createCallCount, 0);
    expect(repo.createVnpayUrlCallCount, 0);
    expect(repo.reconcileCallCount, 0);
  });

  test('multiple pending deposits stop creation', () async {
    final repo =
        FakePaymentRepository()..paymentsToReturn = [receipt(), receipt()];
    await runEvent(
      repo,
      const CreatePaymentRequested(
        'CASH_CONTRACT',
        PaymentMethod.cashOnHandover,
      ),
      (state) => state is PaymentError,
    );
    expect(repo.createCallCount, 0);
  });

  test('cash creation timeout recovers by GET without another POST', () async {
    final repo =
        FakePaymentRepository()
          ..paymentReadResults = [
            [],
            [receipt()],
          ]
          ..createError = const PaymentRequestUncertain('Synthetic timeout');
    final states = await runEvent(
      repo,
      const CreatePaymentRequested(
        'CASH_CONTRACT',
        PaymentMethod.cashOnHandover,
      ),
      (state) => state is PaymentCreatePending,
    );
    expect(repo.createCallCount, 1);
    expect(repo.getPaymentsCallCount, 2);
    expect(states.whereType<PaymentCreateSuccess>(), isEmpty);
    expect(repo.reconcileCallCount, 0);
  });

  for (final status in ['CHO_THANH_TOAN', 'THANH_CONG', 'THAT_BAI']) {
    test(
      'cash status $status is read without confirmation or QueryDR',
      () async {
        final repo =
            FakePaymentRepository()
              ..singlePaymentToReturn = receipt(status: status);
        final states = await runEvent(
          repo,
          const CheckPaymentStatus('CASH_CONTRACT', paymentId: 'CASH_RECEIPT'),
          (state) =>
              state is PaymentCreateSuccess ||
              state is PaymentStatusChecked ||
              state is PaymentError,
        );
        expect(repo.getPaymentByIdCallCount, 1);
        expect(repo.createCallCount, 0);
        expect(repo.createVnpayUrlCallCount, 0);
        expect(repo.reconcileCallCount, 0);
        expect(
          states.whereType<PaymentCreateSuccess>().isNotEmpty,
          status == 'THANH_CONG',
        );
      },
    );
  }

  for (final invalid in [
    receipt(contractId: 'OTHER_CONTRACT', status: 'THANH_CONG'),
    receipt(type: 'TIEN_THUE', status: 'THANH_CONG'),
  ]) {
    test(
      'cash check rejects ${invalid.maHopDong}/${invalid.loaiThanhToan}',
      () async {
        final repo = FakePaymentRepository()..singlePaymentToReturn = invalid;
        final states = await runEvent(
          repo,
          const CheckPaymentStatus('CASH_CONTRACT', paymentId: 'CASH_RECEIPT'),
          (state) => state is PaymentError,
        );
        expect(states.whereType<PaymentCreateSuccess>(), isEmpty);
        expect(repo.reconcileCallCount, 0);
      },
    );
  }

  testWidgets('cash refresh waits for the staff-confirmed server status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo =
        FakePaymentRepository()
          ..paymentsToReturn = [receipt()]
          ..singlePaymentToReturn = receipt();
    final contract = ContractModel(
      contractId: 'CASH_CONTRACT',
      date: DateTime(2026),
      lessorName: 'Synthetic',
      lessorAddress: 'Synthetic',
      lessorPhone: '000',
      lesseeName: 'Synthetic',
      lesseeId: 'Synthetic',
      lesseePhone: '000',
      deviceName: 'Synthetic',
      deviceModel: 'Synthetic',
      quantity: 1,
      pricePerDay: 1000,
      pickupDate: DateTime(2026),
      returnDate: DateTime(2026, 1, 2),
      rentalDays: 1,
      branchName: 'Synthetic',
      rentalTotal: 1000,
      deposit: 1000,
      totalAmount: 2000,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => PaymentPage(contract: contract, repository: repo),
        ),
        GoRoute(
          path: '/payment/success',
          builder:
              (_, _) => const Scaffold(body: Text('Server confirmed receipt')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 100));
    final check = find.text('Kiểm tra trạng thái');
    expect(check, findsOneWidget);
    expect(find.textContaining('5.000.000'), findsNothing);
    expect(find.textContaining('POS quẹt thẻ'), findsNothing);
    // The footer uses the actual receipt amount, even when the contract is stale.
    expect(find.text(const AppMoneyFormatter().format(250000)), findsOneWidget);
    await tester.tap(check);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.getPaymentByIdCallCount, 1);
    expect(find.text('Server confirmed receipt'), findsNothing);
    repo.singlePaymentToReturn = receipt(status: 'THANH_CONG');
    await tester.tap(check);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Server confirmed receipt'), findsOneWidget);
    expect(repo.createCallCount, 0);
    expect(repo.createVnpayUrlCallCount, 0);
    expect(repo.reconcileCallCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
