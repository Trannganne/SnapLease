import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/features/contract/data/repositories/dio_contract_signing_repository.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_signing_cubit.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_signing_state.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Every request terminates in this adapter; no socket or live service is used.
class _SigningAdapter implements HttpClientAdapter {
  final List<ResponseBody> replies;
  final DioExceptionType? failure;
  final requests = <RequestOptions>[];
  final pdfBodies = <List<int>>[];

  _SigningAdapter(this.replies, {this.failure});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      if (options.path.endsWith('/tep-pdf')) pdfBodies.add(bytes);
    }
    if (options.path.endsWith('/yeu-cau-ky') || options.path.endsWith('/ky')) {
      if (failure != null) {
        throw DioException(requestOptions: options, type: failure!);
      }
    }
    if (replies.isEmpty) throw StateError('Unexpected extra request');
    return replies.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ContractModel _contract() => ContractModel(
  contractId: 'HD_OFFLINE_SIGNING_TEST',
  date: DateTime(2026, 10, 22),
  lessorName: 'Test store',
  lessorAddress: 'Test address',
  lessorPhone: '',
  lesseeName: 'Test customer',
  lesseeId: '',
  lesseePhone: '',
  deviceName: 'Test camera',
  deviceModel: 'Test model',
  quantity: 1,
  pricePerDay: 100,
  pickupDate: DateTime(2026, 10, 27, 8),
  returnDate: DateTime(2026, 10, 29, 8),
  rentalDays: 2,
  branchName: 'Test branch',
  rentalTotal: 200,
  deposit: 40,
  totalAmount: 200,
  status: 'CHO_KY',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dio = ApiClient.instance;
  late HttpClientAdapter originalAdapter;
  late DioContractSigningRepository repository;
  final contract = _contract();
  final pdf = Uint8List.fromList(utf8.encode('%PDF-offline-test'));
  const basePath = '/api/hop-dong/HD_OFFLINE_SIGNING_TEST';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalAdapter = dio.httpClientAdapter;
    repository = DioContractSigningRepository();
  });

  tearDown(() => dio.httpClientAdapter = originalAdapter);

  test(
    '202 emailNhan maps after one PDF upload and one signing request',
    () async {
      final adapter = _SigningAdapter([
        _json({}, 200),
        _json({
          'maXacNhan': 'OFFLINE_CONFIRMATION',
          'emailNhan': 't***@example.invalid',
          'emailMask': 'legacy@example.invalid',
          'hetHanLuc': '2026-10-22T05:10:00Z',
          'kenhGui': 'EMAIL',
          'maOtp': null,
        }, 202),
      ]);
      dio.httpClientAdapter = adapter;

      final result = await repository.uploadPdfAndRequestOtp(
        contract,
        pdf,
        true,
      );

      expect(result.maXacNhan, 'OFFLINE_CONFIRMATION');
      expect(result.emailMask, 't***@example.invalid');
      expect(result.expiredAt, DateTime.utc(2026, 10, 22, 5, 10));
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'PUT $basePath/tep-pdf',
        'POST $basePath/yeu-cau-ky',
      ]);
      expect(adapter.pdfBodies, [pdf.toList()]);
      expect(adapter.requests.last.data, {'daDongYDieuKhoan': true});
    },
  );

  test('legacy emailMask response remains compatible', () async {
    dio.httpClientAdapter = _SigningAdapter([
      _json({}, 200),
      _json({
        'maXacNhan': 'OFFLINE_CONFIRMATION',
        'emailMask': 'l***@example.invalid',
        'hetHanLuc': '2026-10-22T05:10:00Z',
      }, 202),
    ]);

    final result = await repository.uploadPdfAndRequestOtp(contract, pdf, true);

    expect(result.emailMask, 'l***@example.invalid');
  });

  test('SMTP 503 displays ProblemDetails title without retrying', () async {
    const title =
        'Không thể gửi OTP qua email. Yêu cầu ký đã được hủy; vui lòng thử lại.';
    final adapter = _SigningAdapter([
      _json({}, 200),
      _json({
        'title': title,
        'status': 503,
        'detail': 'Secondary message',
      }, 503),
    ]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA(title),
    );

    expect(adapter.requests, hasLength(2));
  });

  test('failed PDF upload stops before requesting OTP', () async {
    final adapter = _SigningAdapter([
      _json({'loi': 'Không thể lưu PDF.'}, 400),
    ]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA('Không thể lưu PDF.'),
    );

    expect(adapter.requests.map((r) => r.path), ['$basePath/tep-pdf']);
  });

  test('verification keeps legacy loi ahead of ProblemDetails title', () async {
    final adapter = _SigningAdapter([
      _json({'loi': 'Yêu cầu ký đã hủy.', 'title': 'Generic error'}, 400),
    ]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', 'dummy', true),
      throwsA('Yêu cầu ký đã hủy.'),
    );

    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'PUT $basePath/ky',
    ]);
  });

  test('verification also displays ProblemDetails title', () async {
    dio.httpClientAdapter = _SigningAdapter([
      _json({'title': 'Hợp đồng đã quá hạn ký.'}, 409),
    ]);

    await expectLater(
      repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', 'dummy', true),
      throwsA('Hợp đồng đã quá hạn ký.'),
    );
  });

  test('invalid loi/title values fall back to nonempty detail', () async {
    dio.httpClientAdapter = _SigningAdapter([
      _json({}, 200),
      _json({
        'loi': 123,
        'title': '  ',
        'detail': 'Yêu cầu không còn hiệu lực.',
      }, 400),
    ]);

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA('Yêu cầu không còn hiệu lực.'),
    );
  });

  test(
    'empty HTTP 500 ends loading as a server failure without requesting OTP again',
    () async {
      final adapter = _SigningAdapter([
        _json({}, 200),
        ResponseBody.fromString('', 500),
      ]);
      dio.httpClientAdapter = adapter;
      final cubit = ContractSigningCubit(repository);
      final states = <ContractSigningState>[];
      final subscription = cubit.stream.listen(states.add);
      try {
        await cubit.requestOtp(contract, pdf, true);
        await Future<void>.delayed(Duration.zero);

        expect(states, [
          isA<ContractSigningLoading>(),
          isA<ContractSigningFailure>(),
        ]);
        expect(
          (cubit.state as ContractSigningFailure).error,
          'Máy chủ gặp lỗi khi yêu cầu OTP (HTTP 500). Vui lòng liên hệ hỗ trợ.',
        );
        expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
          'PUT $basePath/tep-pdf',
          'POST $basePath/yeu-cau-ky',
        ]);
      } finally {
        await subscription.cancel();
        await cubit.close();
      }
    },
  );

  test('empty PDF server failure names upload and never requests OTP', () async {
    final adapter = _SigningAdapter([ResponseBody.fromString('', 500)]);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA(
        'Máy chủ gặp lỗi khi tải PDF hợp đồng (HTTP 500). Vui lòng liên hệ hỗ trợ.',
      ),
    );
    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
      'PUT $basePath/tep-pdf',
    ]);
  });

  test(
    'non-map error response uses fallback instead of throwing a type error',
    () async {
      dio.httpClientAdapter = _SigningAdapter([
        _json({}, 200),
        ResponseBody.fromString('Service unavailable', 503),
      ]);

      await expectLater(
        repository.uploadPdfAndRequestOtp(contract, pdf, true),
        throwsA(
          'Máy chủ gặp lỗi khi yêu cầu OTP (HTTP 503). Vui lòng liên hệ hỗ trợ.',
        ),
      );
    },
  );

  test('request timeout reports an unknown outcome and never retries', () async {
    final adapter = _SigningAdapter([
      _json({}, 200),
    ], failure: DioExceptionType.receiveTimeout);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA(
        'Hết thời gian chờ khi yêu cầu OTP. Chưa xác định kết quả; vui lòng tải lại trạng thái trước khi thử lại.',
      ),
    );

    expect(adapter.requests, hasLength(2));
  });

  test('connection failure is distinguished from an HTTP response', () async {
    final adapter = _SigningAdapter([
      _json({}, 200),
    ], failure: DioExceptionType.connectionError);
    dio.httpClientAdapter = adapter;

    await expectLater(
      repository.uploadPdfAndRequestOtp(contract, pdf, true),
      throwsA(
        'Không thể kết nối máy chủ khi yêu cầu OTP. Vui lòng kiểm tra kết nối.',
      ),
    );
    expect(adapter.requests, hasLength(2));
  });

  test(
    'verification timeout reads status once and keeps fallback while unsigned',
    () async {
      final adapter = _SigningAdapter([
        _json({'maHopDong': contract.contractId, 'trangThai': 'CHO_KY'}, 200),
      ], failure: DioExceptionType.receiveTimeout);
      dio.httpClientAdapter = adapter;

      await expectLater(
        repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', 'dummy', true),
        throwsA(
          'Hết thời gian chờ khi xác nhận OTP. Chưa xác định kết quả; vui lòng tải lại trạng thái trước khi thử lại.',
        ),
      );

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'PUT $basePath/ky',
        'GET $basePath',
      ]);
    },
  );

  test(
    'verification HTTP 500 checks status without retrying or claiming success',
    () async {
      final adapter = _SigningAdapter([
        ResponseBody.fromString('', 500),
        _json({'maHopDong': contract.contractId, 'trangThai': 'CHO_KY'}, 200),
      ]);
      dio.httpClientAdapter = adapter;

      await expectLater(
        repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', 'dummy', true),
        throwsA(
          'Máy chủ gặp lỗi khi xác nhận OTP (HTTP 500). Vui lòng liên hệ hỗ trợ.',
        ),
      );
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'PUT $basePath/ky',
        'GET $basePath',
      ]);
    },
  );

  test(
    'Vietnamese signing deadline without an offset has the correct instant',
    () async {
      dio.httpClientAdapter = _SigningAdapter([
        _json({}, 200),
        _json({
          'maXacNhan': 'OFFLINE_CONFIRMATION',
          'emailNhan': 't***@example.invalid',
          'hetHanLuc': '2026-11-01T09:05:00',
        }, 202),
      ]);
      final result = await repository.uploadPdfAndRequestOtp(
        contract,
        pdf,
        true,
      );
      expect(result.expiredAt.toUtc(), DateTime.utc(2026, 11, 1, 2, 5));
    },
  );

  test(
    'verification timeout accepts only a signing state confirmed by GET',
    () async {
      final adapter = _SigningAdapter([
        _json({'maHopDong': contract.contractId, 'trangThai': 'DA_KY'}, 200),
      ], failure: DioExceptionType.receiveTimeout);
      dio.httpClientAdapter = adapter;
      final result = await repository.verifyOtp(
        contract,
        'OFFLINE_CONFIRMATION',
        '123456',
        true,
      );
      expect(result.status, 'DA_KY');
      expect(adapter.requests.map((r) => r.method), ['PUT', 'GET']);
    },
  );

  test(
    'a canceled contract read is never reported as signing success',
    () async {
      final adapter = _SigningAdapter([
        _json({}, 200),
        _json({'maHopDong': contract.contractId, 'trangThai': 'DA_HUY'}, 200),
      ]);
      dio.httpClientAdapter = adapter;
      await expectLater(
        repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', '123456', true),
        throwsA(contains('chưa xác nhận')),
      );
      expect(adapter.requests.map((r) => r.method), ['PUT', 'GET']);
    },
  );

  test(
    'a signed response for a different contract cannot authorize payment',
    () async {
      dio.httpClientAdapter = _SigningAdapter([
        _json({'maHopDong': 'OTHER', 'trangThai': 'DA_KY'}, 200),
        _json({'maHopDong': contract.contractId, 'trangThai': 'CHO_KY'}, 200),
      ]);
      await expectLater(
        repository.verifyOtp(contract, 'OFFLINE_CONFIRMATION', '123456', true),
        throwsA(contains('chưa xác nhận')),
      );
    },
  );
}
