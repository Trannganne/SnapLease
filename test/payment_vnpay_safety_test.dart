import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/features/payment/bloc/payment_bloc.dart';
import 'package:rentcam/features/payment/bloc/payment_event.dart';
import 'package:rentcam/features/payment/bloc/payment_state.dart';
import 'package:rentcam/features/payment/data/payment_repository.dart';
import 'package:rentcam/features/payment/domain/enums/payment_method.dart';
import 'package:rentcam/features/payment/domain/models/payment_model.dart';
import 'package:rentcam/features/payment/presentation/payment_result_page.dart';
import 'package:rentcam/features/payment/presentation/payment_page.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';

PaymentModel payment(
  String status, {
  String kind = 'TIEN_COC',
  bool attemptFailed = false,
}) => PaymentModel(
  maThanhToan: 'SYN_PAY',
  maHopDong: 'SYN_CONTRACT',
  soTien: 1000,
  loaiThanhToan: kind,
  phuongThuc: 'VI_DIEN_TU',
  nhaCungCap: 'VNPAY',
  trangThai: status,
  duongDanThanhToan: 'https://sandbox.vnpayment.vn/synthetic-only',
  lastVnpayAttemptFailed: attemptFailed,
);

class ControlledRepository implements PaymentRepository {
  Future<List<PaymentModel>> Function()? read;
  int creates = 0, links = 0, gets = 0, reconciles = 0;
  PaymentModel current = payment('CHO_THANH_TOAN');
  Exception? linkError;
  @override
  Future<List<PaymentModel>> getPayments(String id) async =>
      read == null ? [] : read!();
  @override
  Future<PaymentModel> createDepositPayment(String id, String method) async {
    creates++;
    return current;
  }

  @override
  Future<PaymentModel> createVnpayPaymentUrl(String id) async {
    links++;
    if (linkError != null) throw linkError!;
    return current;
  }

  @override
  Future<PaymentModel> getPaymentById(String id) async {
    gets++;
    return current;
  }

  @override
  Future<PaymentModel> reconcileVnpayPayment(String id) async {
    reconciles++;
    return current;
  }
}

void main() {
  for (final scenario in [
    ('SYN_PAY', 'CHO_THANH_TOAN', true),
    ('FOREIGN_PAY', 'CHO_THANH_TOAN', false),
    ('SYN_PAY', 'THANH_CONG', false),
  ]) {
    test(
      'verified failed attempt preserves canonical ${scenario.$2} for ${scenario.$1}',
      () async {
        final dio = Dio();
        final requests = <String>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add('${options.method} ${options.path}');
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data:
                      options.method == 'POST'
                          ? {
                            'maThanhToan': scenario.$1,
                            'thanhCong': false,
                            'trangThaiYeuCauVnpay': 'THAT_BAI',
                          }
                          : {
                            'maThanhToan': 'SYN_PAY',
                            'maHopDong': 'SYN_CONTRACT',
                            'soTien': 1000,
                            'trangThai': scenario.$2,
                            'loaiThanhToan': 'TIEN_COC',
                            'phuongThuc': 'VI_DIEN_TU',
                          },
                ),
              );
            },
          ),
        );
        final actual = await PaymentRepository(
          dio: dio,
        ).reconcileVnpayPayment('SYN_PAY');
        expect(actual.trangThai, scenario.$2);
        expect(actual.lastVnpayAttemptFailed, scenario.$3);
        expect(requests, [
          'POST /api/thanh-toan/SYN_PAY/vnpay/doi-soat',
          'GET /api/thanh-toan/SYN_PAY',
        ]);
        dio.close();
      },
    );
  }

  testWidgets(
    'failed reconciled attempt is shown as unsuccessful while collection stays unpaid',
    (tester) async {
      final repo =
          ControlledRepository()
            ..current = payment('CHO_THANH_TOAN', attemptFailed: true);
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentResultPage(paymentId: 'SYN_PAY', repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Thanh toán không thành công'), findsOneWidget);
      expect(find.text('Thanh toán tiền cọc thành công!'), findsNothing);
      expect(repo.current.trangThai, 'CHO_THANH_TOAN');
      expect(repo.links, 0);
      expect(repo.creates, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('link HTTP500 is uncertain, not authorization to POST again', () async {
    final dio = Dio();
    var posts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          posts++;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 500,
                data: {'title': 'Synthetic error'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      PaymentRepository(dio: dio).createVnpayPaymentUrl('SYN_PAY'),
      throwsA(isA<PaymentRequestUncertain>()),
    );
    expect(posts, 1);
    dio.close();
  });

  test(
    'QueryDR timeout reconciles with one canonical GET and no link POST',
    () async {
      final dio = Dio();
      final requests = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add('${options.method} ${options.path}');
            if (options.method == 'POST') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'maThanhToan': 'SYN_PAY',
                    'maHopDong': 'SYN_CONTRACT',
                    'soTien': 1000,
                    'trangThai': 'THANH_CONG',
                    'loaiThanhToan': 'TIEN_COC',
                    'phuongThuc': 'VI_DIEN_TU',
                  },
                ),
              );
            }
          },
        ),
      );
      final actual = await PaymentRepository(
        dio: dio,
      ).reconcileVnpayPayment('SYN_PAY');
      expect(actual.trangThai, 'THANH_CONG');
      expect(requests, [
        'POST /api/thanh-toan/SYN_PAY/vnpay/doi-soat',
        'GET /api/thanh-toan/SYN_PAY',
      ]);
      dio.close();
    },
  );

  test('two concurrent taps create and open only one collection', () async {
    final gate = Completer<List<PaymentModel>>();
    final repo = ControlledRepository()..read = () => gate.future;
    final bloc = PaymentBloc(repository: repo);
    final states = <PaymentState>[];
    final sub = bloc.stream.listen(states.add);
    final done = bloc.stream.firstWhere((s) => s is PaymentCreatePending);
    bloc.add(const CreatePaymentRequested('SYN_CONTRACT', PaymentMethod.vnpay));
    bloc.add(const CreatePaymentRequested('SYN_CONTRACT', PaymentMethod.vnpay));
    await Future<void>.delayed(Duration.zero);
    gate.complete([]);
    await done;
    expect(repo.creates, 1);
    expect(repo.links, 1);
    expect(states.whereType<PaymentOpenUrl>().length, 1);
    await sub.cancel();
    await bloc.close();
  });

  test('old pending GET cannot overwrite a newer canonical success', () async {
    final gate = Completer<List<PaymentModel>>();
    final repo = ControlledRepository();
    repo.read = () => gate.future;
    repo.current = payment('THANH_CONG');
    final bloc = PaymentBloc(repository: repo);
    bloc.add(const LoadPaymentStatus('SYN_CONTRACT'));
    await Future<void>.delayed(Duration.zero);
    final done = bloc.stream.firstWhere((s) => s is PaymentCreateSuccess);
    bloc.add(const CheckPaymentStatus('SYN_CONTRACT', paymentId: 'SYN_PAY'));
    await done;
    gate.complete([payment('CHO_THANH_TOAN')]);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<PaymentCreateSuccess>());
    await bloc.close();
  });

  test(
    'typed uncertain link recovers payment ID without opening gateway',
    () async {
      var reads = 0;
      final repo =
          ControlledRepository()
            ..linkError = const PaymentRequestUncertain(
              'Synthetic unknown outcome',
            );
      repo.read = () async => ++reads == 1 ? [] : [repo.current];
      final bloc = PaymentBloc(repository: repo);
      final states = <PaymentState>[];
      final sub = bloc.stream.listen(states.add);
      final done = bloc.stream.firstWhere((s) => s is PaymentError);
      bloc.add(
        const CreatePaymentRequested('SYN_CONTRACT', PaymentMethod.vnpay),
      );
      await done;
      expect(reads, 2);
      expect(repo.creates, 1);
      expect(repo.links, 1);
      expect(states.whereType<PaymentOpenUrl>(), isEmpty);
      await sub.cancel();
      await bloc.close();
    },
  );

  testWidgets(
    'result page resume reads canonical state without extra QueryDR or checkout',
    (tester) async {
      final repo = ControlledRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentResultPage(paymentId: 'SYN_PAY', repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(repo.reconciles, 1);
      repo.current = payment('THANH_CONG');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      expect(repo.gets, 2);
      expect(repo.reconciles, 1);
      expect(repo.links, 0);
      expect(find.text('Thanh toán tiền cọc thành công!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'settlement collection success is not labelled deposit or contract completion',
    (tester) async {
      final repo =
          ControlledRepository()
            ..current = payment('THANH_CONG', kind: 'THU_QUYET_TOAN');
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentResultPage(paymentId: 'SYN_PAY', repository: repo),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Thanh toán quyết toán thành công!'), findsOneWidget);
      expect(find.text('Thanh toán tiền cọc thành công!'), findsNothing);
      expect(repo.reconciles, 0);
      expect(repo.links, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'explicit reopen goes through Backend attempt guard instead of cached failed URL',
    (tester) async {
      final repo =
          ControlledRepository()
            ..linkError = const PaymentRequestUncertain(
              'Synthetic unresolved result',
            );
      repo.read = () async => [repo.current];
      final contract = ContractModel(
        contractId: 'SYN_CONTRACT',
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
      await tester.pumpWidget(
        MaterialApp(home: PaymentPage(contract: contract, repository: repo)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      final open = find.text('Mở VNPAY');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump(const Duration(milliseconds: 50));
      expect(repo.links, 1);
      expect(repo.creates, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
