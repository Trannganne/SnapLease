import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/features/payment/bloc/payment_bloc.dart';
import 'package:rentcam/features/payment/bloc/payment_event.dart';
import 'package:rentcam/features/payment/bloc/payment_state.dart';
import 'package:rentcam/features/payment/data/payment_repository.dart';
import 'package:rentcam/features/payment/domain/enums/payment_method.dart';
import 'package:rentcam/features/payment/domain/models/payment_model.dart';

class FakePaymentRepository implements PaymentRepository {
  List<PaymentModel> paymentsToReturn = [];
  PaymentModel? createdPaymentToReturn;
  PaymentModel? singlePaymentToReturn;
  PaymentModel? vnpayPaymentToReturn;
  bool createCalled = false;
  bool createVnpayUrlCalled = false;
  int createCallCount = 0;
  int createVnpayUrlCallCount = 0;
  Exception? createError;
  Exception? vnpayError;
  List<List<PaymentModel>>? paymentReadResults;
  int getPaymentsCallCount = 0;
  int getPaymentByIdCallCount = 0;
  int reconcileCallCount = 0;

  @override
  Future<PaymentModel> reconcileVnpayPayment(String paymentId) async {
    reconcileCallCount++;
    return singlePaymentToReturn!;
  }

  @override
  Future<List<PaymentModel>> getPayments(String contractId) async {
    getPaymentsCallCount++;
    final reads = paymentReadResults;
    if (reads != null && getPaymentsCallCount <= reads.length) {
      return reads[getPaymentsCallCount - 1];
    }
    return paymentsToReturn;
  }

  @override
  Future<PaymentModel> createDepositPayment(
    String contractId,
    String phuongThuc,
  ) async {
    createCalled = true;
    createCallCount++;
    if (createError != null) throw createError!;
    if (createdPaymentToReturn != null) {
      return createdPaymentToReturn!;
    }
    throw Exception('Error creating payment');
  }

  @override
  Future<PaymentModel> getPaymentById(String paymentId) async {
    getPaymentByIdCallCount++;
    if (singlePaymentToReturn != null) {
      return singlePaymentToReturn!;
    }
    throw Exception('Payment not found');
  }

  @override
  Future<PaymentModel> createVnpayPaymentUrl(String paymentId) async {
    createVnpayUrlCalled = true;
    createVnpayUrlCallCount++;
    if (vnpayError != null) throw vnpayError!;
    if (vnpayPaymentToReturn != null) {
      return vnpayPaymentToReturn!;
    }
    throw Exception('Error creating VNPAY URL');
  }
}

void main() {
  group('Uncertain VNPAY requests stop after a canonical read', () {
    PaymentModel payment({String status = 'CHO_THANH_TOAN'}) => PaymentModel(
      maThanhToan: 'synthetic-payment',
      maHopDong: 'synthetic-contract',
      soTien: 1000000,
      loaiThanhToan: 'TIEN_COC',
      phuongThuc: 'VI_DIEN_TU',
      nhaCungCap: 'VNPAY',
      trangThai: status,
    );

    for (final stage in ['deposit', 'new link', 'existing link']) {
      test(
        '$stage timeout never retries a POST or opens the gateway',
        () async {
          final pending = payment();
          final repo =
              FakePaymentRepository()
                ..paymentReadResults = [
                  stage == 'existing link' ? [pending] : [],
                  [pending],
                ]
                ..createdPaymentToReturn = pending;
          if (stage == 'deposit') {
            repo.createError = Exception('connection timeout');
          } else {
            repo.vnpayError = Exception('connection timeout');
          }
          final bloc = PaymentBloc(repository: repo);
          final states = <PaymentState>[];
          final subscription = bloc.stream.listen(states.add);
          final stopped = bloc.stream.firstWhere((s) => s is PaymentError);
          bloc.add(
            const CreatePaymentRequested(
              'synthetic-contract',
              PaymentMethod.vnpay,
            ),
          );
          await stopped.timeout(const Duration(seconds: 2));

          expect(repo.getPaymentsCallCount, 2);
          expect(repo.createCallCount, stage == 'existing link' ? 0 : 1);
          expect(repo.createVnpayUrlCallCount, stage == 'deposit' ? 0 : 1);
          expect(repo.reconcileCallCount, 0);
          expect(states.whereType<PaymentOpenUrl>(), isEmpty);
          expect(states.whereType<PaymentCreateSuccess>(), isEmpty);
          expect(
            states.whereType<PaymentCreatePending>().single.payment.maThanhToan,
            pending.maThanhToan,
          );
          expect(
            (states.last as PaymentError).message,
            contains('kiểm tra trạng thái'),
          );
          await subscription.cancel();
          await bloc.close();
        },
      );
    }

    test(
      'a success found by GET after a timeout needs no further POST',
      () async {
        final pending = payment();
        final success = payment(status: 'THANH_CONG');
        final repo =
            FakePaymentRepository()
              ..paymentReadResults = [
                [],
                [success],
              ]
              ..createdPaymentToReturn = pending
              ..vnpayError = Exception('connection timeout');
        final bloc = PaymentBloc(repository: repo);
        final finished = bloc.stream.firstWhere(
          (s) => s is PaymentCreateSuccess,
        );
        bloc.add(
          const CreatePaymentRequested(
            'synthetic-contract',
            PaymentMethod.vnpay,
          ),
        );
        final state =
            await finished.timeout(const Duration(seconds: 2))
                as PaymentCreateSuccess;
        expect(state.payment.trangThai, 'THANH_CONG');
        expect(repo.createCallCount, 1);
        expect(repo.createVnpayUrlCallCount, 1);
        expect(repo.getPaymentsCallCount, 2);
        expect(repo.reconcileCallCount, 0);
        await bloc.close();
      },
    );

    test(
      'unknown deposit timeout with no row does not create another payment',
      () async {
        final repo =
            FakePaymentRepository()
              ..createError = Exception('connection timeout');
        final bloc = PaymentBloc(repository: repo);
        final stopped = bloc.stream.firstWhere((s) => s is PaymentError);
        bloc.add(
          const CreatePaymentRequested(
            'synthetic-contract',
            PaymentMethod.vnpay,
          ),
        );
        await stopped.timeout(const Duration(seconds: 2));
        expect(repo.createCallCount, 1);
        expect(repo.createVnpayUrlCallCount, 0);
        expect(repo.getPaymentsCallCount, 2);
        expect(repo.reconcileCallCount, 0);
        await bloc.close();
      },
    );
  });

  group('PaymentModel Tests', () {
    test('PaymentModel parses bank transfer fields correctly', () {
      final json = {
        'maThanhToan': 'pay-123',
        'maHopDong': 'hd-456',
        'soTien': 500000,
        'loaiThanhToan': 'TIEN_COC',
        'phuongThuc': 'CHUYEN_KHOAN',
        'trangThai': 'CHO_THANH_TOAN',
        'noiDungChuyenKhoan': 'SNAPLEASE HD456',
        'nganHang': 'BIDV',
        'maBin': '970418',
        'soTaiKhoan': '6801925893',
        'chuTaiKhoan': 'TRAN THI KIM NGAN',
        'thongBao': 'Vui lòng chuyển khoản đúng nội dung',
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.maThanhToan, 'pay-123');
      expect(payment.maHopDong, 'hd-456');
      expect(payment.soTien, 500000);
      expect(payment.loaiThanhToan, 'TIEN_COC');
      expect(payment.phuongThuc, 'CHUYEN_KHOAN');
      expect(payment.trangThai, 'CHO_THANH_TOAN');
      expect(payment.noiDungChuyenKhoan, 'SNAPLEASE HD456');
      expect(payment.nganHang, 'BIDV');
      expect(payment.maBin, '970418');
      expect(payment.soTaiKhoan, '6801925893');
      expect(payment.chuTaiKhoan, 'TRAN THI KIM NGAN');
      expect(payment.thongBao, 'Vui lòng chuyển khoản đúng nội dung');
    });

    test('PaymentModel parses VNPAY fields correctly', () {
      final json = {
        'maThanhToan': 'pay-vnpay-1',
        'maHopDong': 'hd-789',
        'soTien': 1500000,
        'loaiThanhToan': 'TIEN_COC',
        'phuongThuc': 'VI_DIEN_TU',
        'trangThai': 'CHO_THANH_TOAN',
        'nhaCungCap': 'VNPAY',
        'maThamChieu': 'vnp_ref_123',
        'duongDanThanhToan':
            'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?x=1',
        'thoiGianHetHan': '2026-10-11T20:30:00Z',
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.maThanhToan, 'pay-vnpay-1');
      expect(payment.phuongThuc, 'VI_DIEN_TU');
      expect(payment.nhaCungCap, 'VNPAY');
      expect(payment.maThamChieu, 'vnp_ref_123');
      expect(
        payment.duongDanThanhToan,
        'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?x=1',
      );
      expect(payment.thoiGianHetHan, DateTime.parse('2026-10-11T20:30:00Z'));
    });
  });

  group('PaymentBloc Bank Transfer Tests', () {
    late FakePaymentRepository fakeRepo;
    late PaymentBloc bloc;

    setUp(() {
      fakeRepo = FakePaymentRepository();
      bloc = PaymentBloc(repository: fakeRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test(
      'Tạo yêu cầu cọc chuyển khoản thành công khi chưa có cọc chờ',
      () async {
        final newPayment = PaymentModel(
          maThanhToan: 'pay-001',
          maHopDong: 'hd-001',
          soTien: 1000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'CHUYEN_KHOAN',
          trangThai: 'CHO_THANH_TOAN',
          noiDungChuyenKhoan: 'SNAPLEASE HD001',
          nganHang: 'BIDV',
          maBin: '970418',
          soTaiKhoan: '6801925893',
          chuTaiKhoan: 'TRAN THI KIM NGAN',
        );

        fakeRepo.paymentsToReturn = [];
        fakeRepo.createdPaymentToReturn = newPayment;

        final expectedStates = <PaymentState>[];
        final subscription = bloc.stream.listen((state) {
          expectedStates.add(state);
        });

        bloc.add(const CreatePaymentRequested('hd-001', PaymentMethod.online));

        await Future.delayed(const Duration(milliseconds: 200));

        expect(expectedStates, contains(isA<PaymentCreating>()));
        final pendingState =
            expectedStates.firstWhere((s) => s is PaymentCreatePending)
                as PaymentCreatePending;

        expect(pendingState.payment.soTaiKhoan, '6801925893');
        expect(pendingState.payment.chuTaiKhoan, 'TRAN THI KIM NGAN');
        expect(pendingState.payment.trangThai, 'CHO_THANH_TOAN');
        expect(fakeRepo.createCalled, isTrue);

        await subscription.cancel();
      },
    );

    test('Chống trùng: Mở lại giao dịch đang chờ, không POST mới', () async {
      final existingPending = PaymentModel(
        maThanhToan: 'pay-pending-1',
        maHopDong: 'hd-001',
        soTien: 1000000,
        loaiThanhToan: 'TIEN_COC',
        phuongThuc: 'CHUYEN_KHOAN',
        trangThai: 'CHO_THANH_TOAN',
        noiDungChuyenKhoan: 'SNAPLEASE HD001',
        nganHang: 'BIDV',
        maBin: '970418',
        soTaiKhoan: '6801925893',
        chuTaiKhoan: 'TRAN THI KIM NGAN',
      );

      fakeRepo.paymentsToReturn = [existingPending];

      final expectedStates = <PaymentState>[];
      final subscription = bloc.stream.listen((state) {
        expectedStates.add(state);
      });

      bloc.add(const CreatePaymentRequested('hd-001', PaymentMethod.online));

      await Future.delayed(const Duration(milliseconds: 200));

      final pendingState =
          expectedStates.firstWhere((s) => s is PaymentCreatePending)
              as PaymentCreatePending;

      expect(pendingState.payment.maThanhToan, 'pay-pending-1');
      // Không được gọi createDepositPayment mới
      expect(fakeRepo.createCalled, isFalse);

      await subscription.cancel();
    });

    test(
      'Đã có cọc THANH_CONG: Không cho thanh toán lại, chuyển sang PaymentCreateSuccess',
      () async {
        final paidDeposit = PaymentModel(
          maThanhToan: 'pay-paid-1',
          maHopDong: 'hd-001',
          soTien: 1000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'CHUYEN_KHOAN',
          trangThai: 'THANH_CONG',
        );

        fakeRepo.paymentsToReturn = [paidDeposit];

        final expectedStates = <PaymentState>[];
        final subscription = bloc.stream.listen((state) {
          expectedStates.add(state);
        });

        bloc.add(const CreatePaymentRequested('hd-001', PaymentMethod.online));

        await Future.delayed(const Duration(milliseconds: 200));

        final successState =
            expectedStates.firstWhere((s) => s is PaymentCreateSuccess)
                as PaymentCreateSuccess;

        expect(successState.payment.trangThai, 'THANH_CONG');
        expect(fakeRepo.createCalled, isFalse);

        await subscription.cancel();
      },
    );

    test('CheckPaymentStatus chỉ gọi GET để kiểm tra trạng thái', () async {
      final payment = PaymentModel(
        maThanhToan: 'pay-001',
        maHopDong: 'hd-001',
        soTien: 1000000,
        loaiThanhToan: 'TIEN_COC',
        phuongThuc: 'CHUYEN_KHOAN',
        trangThai: 'CHO_THANH_TOAN',
      );

      fakeRepo.singlePaymentToReturn = payment;

      final expectedStates = <PaymentState>[];
      final subscription = bloc.stream.listen((state) {
        expectedStates.add(state);
      });

      bloc.add(const CheckPaymentStatus('hd-001', paymentId: 'pay-001'));

      await Future.delayed(const Duration(milliseconds: 200));

      expect(expectedStates, contains(isA<PaymentChecking>()));
      final checkedState =
          expectedStates.firstWhere((s) => s is PaymentStatusChecked)
              as PaymentStatusChecked;

      expect(checkedState.payment.trangThai, 'CHO_THANH_TOAN');
      expect(checkedState.isStillPending, isTrue);
      expect(fakeRepo.getPaymentByIdCallCount, 1);
      expect(fakeRepo.createCalled, isFalse);

      await subscription.cancel();
    });
  });

  group('PaymentBloc VNPAY Tests', () {
    late FakePaymentRepository fakeRepo;
    late PaymentBloc bloc;

    setUp(() {
      fakeRepo = FakePaymentRepository();
      bloc = PaymentBloc(repository: fakeRepo);
    });

    tearDown(() {
      bloc.close();
    });

    test(
      'Pending VNPAY is reconciled without creating a payment or link',
      () async {
        fakeRepo.singlePaymentToReturn = PaymentModel(
          maThanhToan: 'pay-old',
          maHopDong: 'hd-old',
          soTien: 3000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'VI_DIEN_TU',
          nhaCungCap: 'VNPAY',
          trangThai: 'CHO_THANH_TOAN',
        );
        final checked = bloc.stream.firstWhere(
          (s) => s is PaymentStatusChecked,
        );
        bloc.add(const CheckPaymentStatus('hd-old', paymentId: 'pay-old'));
        final state = await checked as PaymentStatusChecked;
        expect(state.isStillPending, isTrue);
        expect(fakeRepo.reconcileCallCount, 1);
        expect(fakeRepo.createCalled, isFalse);
        expect(fakeRepo.createVnpayUrlCalled, isFalse);
        expect(state.message, isNot(contains('tự động')));
      },
    );

    test(
      'Tạo cọc VNPAY thành công: gọi API tạo cọc rồi sinh link VNPAY, emit PaymentOpenUrl',
      () async {
        final newDeposit = PaymentModel(
          maThanhToan: 'pay-vnpay-01',
          maHopDong: 'hd-vnpay-01',
          soTien: 2000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'VI_DIEN_TU',
          trangThai: 'CHO_THANH_TOAN',
        );

        final vnpayWithUrl = PaymentModel(
          maThanhToan: 'pay-vnpay-01',
          maHopDong: 'hd-vnpay-01',
          soTien: 2000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'VI_DIEN_TU',
          trangThai: 'CHO_THANH_TOAN',
          nhaCungCap: 'VNPAY',
          maThamChieu: 'REF01',
          duongDanThanhToan:
              'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?token=abc',
        );

        fakeRepo.paymentsToReturn = [];
        fakeRepo.createdPaymentToReturn = newDeposit;
        fakeRepo.vnpayPaymentToReturn = vnpayWithUrl;

        final expectedStates = <PaymentState>[];
        final subscription = bloc.stream.listen((state) {
          expectedStates.add(state);
        });

        bloc.add(
          const CreatePaymentRequested('hd-vnpay-01', PaymentMethod.vnpay),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        expect(expectedStates, contains(isA<PaymentCreating>()));
        expect(expectedStates, contains(isA<PaymentOpenUrl>()));
        expect(expectedStates, contains(isA<PaymentCreatePending>()));

        final openUrlState =
            expectedStates.firstWhere((s) => s is PaymentOpenUrl)
                as PaymentOpenUrl;
        expect(
          openUrlState.url,
          'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?token=abc',
        );

        expect(fakeRepo.createCalled, isTrue);
        expect(fakeRepo.createVnpayUrlCalled, isTrue);

        await subscription.cancel();
      },
    );

    test(
      'Xung đột phương thức: Đang có cọc BIDV chờ xử lý thì không cho tạo VNPAY mới',
      () async {
        final existingBidv = PaymentModel(
          maThanhToan: 'pay-bidv-01',
          maHopDong: 'hd-vnpay-02',
          soTien: 1000000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'CHUYEN_KHOAN',
          trangThai: 'CHO_THANH_TOAN',
        );

        fakeRepo.paymentsToReturn = [existingBidv];

        final expectedStates = <PaymentState>[];
        final subscription = bloc.stream.listen((state) {
          expectedStates.add(state);
        });

        bloc.add(
          const CreatePaymentRequested('hd-vnpay-02', PaymentMethod.vnpay),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        expect(expectedStates, contains(isA<PaymentError>()));
        final errorState =
            expectedStates.firstWhere((s) => s is PaymentError) as PaymentError;
        expect(errorState.message, contains('khoản cọc'));
        expect(fakeRepo.createCalled, isFalse);

        await subscription.cancel();
      },
    );

    test(
      'Chống trùng VNPAY: Đã có cọc VNPAY chờ xử lý thì tái sử dụng, không gọi POST tạo cọc mới',
      () async {
        final existingVnpay = PaymentModel(
          maThanhToan: 'pay-vnpay-existing',
          maHopDong: 'hd-vnpay-03',
          soTien: 1500000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'VI_DIEN_TU',
          trangThai: 'CHO_THANH_TOAN',
        );

        final refreshedVnpay = PaymentModel(
          maThanhToan: 'pay-vnpay-existing',
          maHopDong: 'hd-vnpay-03',
          soTien: 1500000,
          loaiThanhToan: 'TIEN_COC',
          phuongThuc: 'VI_DIEN_TU',
          trangThai: 'CHO_THANH_TOAN',
          duongDanThanhToan:
              'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?token=existing',
        );

        fakeRepo.paymentsToReturn = [existingVnpay];
        fakeRepo.vnpayPaymentToReturn = refreshedVnpay;

        final expectedStates = <PaymentState>[];
        final subscription = bloc.stream.listen((state) {
          expectedStates.add(state);
        });

        bloc.add(
          const CreatePaymentRequested('hd-vnpay-03', PaymentMethod.vnpay),
        );

        await Future.delayed(const Duration(milliseconds: 200));

        expect(fakeRepo.createCalled, isFalse); // Không tạo mới
        expect(
          fakeRepo.createVnpayUrlCalled,
          isTrue,
        ); // Nhưng lấy lại URL VNPAY
        expect(expectedStates, contains(isA<PaymentOpenUrl>()));
        expect(expectedStates, contains(isA<PaymentCreatePending>()));

        await subscription.cancel();
      },
    );
  });
}
