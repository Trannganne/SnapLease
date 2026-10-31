import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/domain/models/settlement_view.dart';
import 'package:rentcam/features/contract/presentation/bloc/contract_detail_cubit.dart';
import 'package:rentcam/features/contract/presentation/settlement/settlement_detail_page.dart';

final hash = 'A' * 64;
Map<String, dynamic> fixture({
  num? collect = 0,
  num? refund = 3500000,
  num? recorded = 0,
  num? remaining = 3500000,
  bool acknowledge = false,
}) => {
  'schemaVersion': 2,
  'maHopDong': 'fixture-contract',
  'trangThaiHopDong': 'CHO_HOAN_TRA',
  'trangThaiQuyetToan': 'DA_CHOT',
  'maBamQuyetToan': hash,
  'maQuyetToan': 'fixture-settlement',
  'phienBan': 1,
  'tongNghiaVu': 1500000,
  'thuePhiDaThu': 0,
  'cocDaThu': 5000000,
  'cocKhauTru': 1500000,
  'conPhaiThu': collect,
  'tongDuocHoan': refund,
  'daGhiHoan': recorded,
  'conPhaiHoan': remaining,
  'nhanTra': {
    'thucNhanLuc': '2026-10-25T08:00:00',
    'kiemTraLucUtc': '2026-10-25T01:30:00Z',
    'thietBi': [
      {
        'maChiTietHopDong': 'fixture-detail',
        'tenDongMay': 'Máy thử',
        'soSerial': 'fixture-serial',
        'tinhTrang': 'Đủ máy; dữ liệu tình trạng thực tế',
        'coHuHong': false,
        'thieuPhuKien': false,
        'phuKien': [],
        'ketLuan': 'DAT',
      },
    ],
    'ngoaiLe': [],
  },
  'nghiaVu': [
    {
      'id': 'rent',
      'loai': 'TIEN_THUE',
      'moTa': 'Tiền thuê gốc',
      'soTien': 1000000,
    },
    {
      'id': 'extension',
      'loai': 'PHI_GIA_HAN',
      'moTa': 'Phí gia hạn hiệu lực',
      'soTien': 500000,
    },
  ],
  'nguonThu': [
    {
      'maThanhToan': 'fixture-deposit',
      'loaiThanhToan': 'TIEN_COC',
      'phuongThuc': 'TIEN_MAT',
      'soTien': 5000000,
      'trangThai': 'THANH_CONG',
    },
  ],
  'phanBo': [
    {
      'maThanhToanNguon': 'fixture-deposit',
      'maKhoan': 'rent',
      'soTien': 1000000,
    },
    {
      'maThanhToanNguon': 'fixture-deposit',
      'maKhoan': 'extension',
      'soTien': 500000,
    },
  ],
  'thanhToan':
      acknowledge
          ? [
            {
              'maThanhToan': 'fixture-refund',
              'maHopDong': 'fixture-contract',
              'loaiThanhToan': 'HOAN_COC',
              'soTien': 3500000,
              'phuongThuc': 'TIEN_MAT',
              'trangThai': 'DA_HOAN',
              'thoiGian': '2026-10-25T08:40:00',
            },
          ]
          : [],
  'phanHoi': [],
  'lyDoChan': [],
  'vnpaySanSang': false,
  'hanhDong': {
    'phanHoi': true,
    'thanhToan': false,
    'dongYQuyetToan': false,
    'khoanHoanDuocXacNhan': acknowledge ? ['fixture-refund'] : [],
  },
};

class FakeRepository extends ContractRepository {
  Map<String, dynamic> json;
  int reads = 0, writes = 0;
  SettlementFailure? failure;
  bool operationCommitted = false;
  Completer<void>? wait;
  FakeRepository(this.json) : super(dio: Dio());
  @override
  Future<Map<String, dynamic>> reconcileSettlementOperation(
    String id,
    String operation,
    String kind,
  ) async => {'maHopDong': id, 'daGhiNhan': operationCommitted};
  @override
  Future<SettlementView> getSettlement(String contractId) async {
    reads++;
    await wait?.future;
    return SettlementView.fromJson(json, contractId);
  }

  @override
  Future<void> sendSettlementFeedback(
    String contractId, {
    required String hash,
    required String operationId,
    required String type,
    String? paymentId,
    String? reason,
    String? feedbackId,
    num? expectedAmount,
    String? replySeenAt,
  }) async {
    writes++;
    if (failure != null) throw failure!;
    json['trangThaiHopDong'] = 'HOAN_THANH';
    json['hanhDong'] = {'phanHoi': false, 'khoanHoanDuocXacNhan': []};
  }
}

Future<void> mount(WidgetTester tester, FakeRepository repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SettlementDetailPage(
        contractId: 'fixture-contract',
        repository: repo,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('Server settlement mapping', () {
    test(
      'Schema33 repository keeps the retained refund acknowledgement contract',
      () async {
        final json =
            fixture(acknowledge: true, recorded: 3500000, remaining: 0)
              ..['schemaVersion'] = 3
              ..['phanHoiDuocHoTro'] = false;
        (json['hanhDong'] as Map)['phanHoi'] = false;
        final requests = <RequestOptions>[];
        final dio =
            Dio()
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (request, handler) {
                    requests.add(request);
                    handler.resolve(
                      Response(
                        requestOptions: request,
                        statusCode: 200,
                        data:
                            request.method == 'GET' ? json : {'doiSoat': true},
                      ),
                    );
                  },
                ),
              );
        final repository = ContractRepository(dio: dio);
        final view = await repository.getSettlement('fixture-contract');
        await repository.sendSettlementFeedback(
          'fixture-contract',
          hash: view.hash!,
          operationId: 'fixture-operation',
          type: 'DA_NHAN_HOAN',
          paymentId: view.receivableRefundIds.single,
          expectedAmount: 3500000,
        );
        expect(requests.map((r) => r.method), ['GET', 'POST']);
        expect(
          requests.last.path,
          '/api/hop-dong/fixture-contract/quyet-toan/phan-hoi',
        );
        expect(
          requests.last.data,
          containsPair('maThanhToan', 'fixture-refund'),
        );
        expect(requests.last.data, containsPair('maBamQuyetToan', hash));
        expect(requests.last.data, containsPair('soTienXacNhan', 3500000));
        expect(requests.last.data, containsPair('loai', 'DA_NHAN_HOAN'));
        dio.close();
      },
    );
    test(
      'Schema33 version 3 preserves refund capabilities and review targets',
      () {
        final json =
            fixture(acknowledge: true, recorded: 3500000, remaining: 0)
              ..['schemaVersion'] = 3
              ..['phanHoiDuocHoTro'] = false;
        (json['hanhDong'] as Map)['phanHoi'] = false;
        final view = SettlementView.fromJson(json, 'fixture-contract');
        expect(view.receivableRefundIds, ['fixture-refund']);
        expect(view.allows('phanHoi'), isFalse);
        expect(view.refundEntitlement, 3500000);
        expect(view.refundRecorded, 3500000);
        expect(view.isComplete, isFalse);
        json['trangThaiHopDong'] = 'HOAN_THANH';
        json['thietBiDuocDanhGia'] = [
          'fixture-detail',
          'fixture-second-detail',
        ];
        final completed = SettlementView.fromJson(json, 'fixture-contract');
        expect(completed.isComplete, isTrue);
        expect(completed.reviewEligibleIds, [
          'fixture-detail',
          'fixture-second-detail',
        ]);
      },
    );
    test(
      'Unknown statement versions are rejected instead of guessing capabilities',
      () {
        for (final version in [null, 1, 4, '3']) {
          final json = fixture()..['schemaVersion'] = version;
          expect(
            () => SettlementView.fromJson(json, 'fixture-contract'),
            throwsFormatException,
          );
        }
      },
    );
    test('foreign refund row and malformed child amount rejected', () {
      final foreign = fixture(acknowledge: true);
      (foreign['thanhToan'] as List).first['maHopDong'] = 'foreign';
      expect(
        () => SettlementView.fromJson(foreign, 'fixture-contract'),
        throwsFormatException,
      );
      final invalid = fixture();
      (invalid['nghiaVu'] as List).first['soTien'] = '100';
      expect(
        () => SettlementView.fromJson(invalid, 'fixture-contract'),
        throwsFormatException,
      );
    });
    test(
      'unrecorded refund cannot be acknowledged through forged capability',
      () {
        final invalid = fixture();
        (invalid['hanhDong'] as Map)['khoanHoanDuocXacNhan'] = ['missing'];
        expect(
          () => SettlementView.fromJson(invalid, 'fixture-contract'),
          throwsFormatException,
        );
      },
    );
    test('final state needs typed settlement identity/version', () {
      final invalid = fixture()..remove('phienBan');
      expect(
        () => SettlementView.fromJson(invalid, 'fixture-contract'),
        throwsFormatException,
      );
    });
    test('missing amounts remain unknown', () {
      final json = fixture(
        collect: null,
        refund: null,
        recorded: null,
        remaining: null,
      );
      final view = SettlementView.fromJson(json, 'fixture-contract');
      expect(view.collectionRemaining, isNull);
      expect(view.refundEntitlement, isNull);
    });
    test(
      'wrong contract rejected',
      () => expect(
        () => SettlementView.fromJson(fixture(), 'someone-else'),
        throwsFormatException,
      ),
    );
    test(
      'old aggregate is not a final statement',
      () => expect(
        () => SettlementView.fromJson({
          'maHopDong': 'fixture-contract',
        }, 'fixture-contract'),
        throwsFormatException,
      ),
    );
    test('malformed hash rejected', () {
      final json = fixture()..['maBamQuyetToan'] = 'bad';
      expect(
        () => SettlementView.fromJson(json, 'fixture-contract'),
        throwsFormatException,
      );
    });
    for (final invalid in [-1, double.nan, double.infinity, '0']) {
      test('invalid money $invalid rejected', () {
        final json = fixture()..['conPhaiThu'] = invalid;
        expect(
          () => SettlementView.fromJson(json, 'fixture-contract'),
          throwsFormatException,
        );
      });
    }
    test('recorded refund is separate from entitlement and remaining', () {
      final v = SettlementView.fromJson(
        fixture(recorded: 1000000, remaining: 2500000),
        'fixture-contract',
      );
      expect(v.refundEntitlement, 3500000);
      expect(v.refundRecorded, 1000000);
      expect(v.refundRemaining, 2500000);
    });
    test('stale backend disables actions', () {
      final json = fixture()..['duLieuCanDoiSoat'] = true;
      expect(
        SettlementView.fromJson(json, 'fixture-contract').allows('phanHoi'),
        isFalse,
      );
    });
  });

  group('Customer statement UI', () {
    testWidgets(
      'SQL UTC timestamps without suffix remain distinct from local actual receipt',
      (tester) async {
        final json = fixture();
        (json['nhanTra'] as Map)['kiemTraLucUtc'] = '2026-10-25T01:30:00';
        (json['nhanTra'] as Map)['ghiNhanLucUtc'] = '2026-10-25T01:10:00';
        await mount(tester, FakeRepository(json));
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pump();
        expect(find.text('Thực nhận: 08:00 • 25/10/2026'), findsOneWidget);
        expect(find.text('Ghi nhận: 08:10 • 25/10/2026'), findsOneWidget);
        expect(find.text('Kiểm tra: 08:30 • 25/10/2026'), findsOneWidget);
      },
    );
    testWidgets('Backend decimal amount is displayed without silent rounding', (
      tester,
    ) async {
      await mount(
        tester,
        FakeRepository(fixture(refund: 100.25, remaining: 100.25)),
      );
      expect(find.textContaining('100,25đ'), findsWidgets);
    });
    testWidgets('no-refund agreement requires explicit confirmation', (
      tester,
    ) async {
      final json = fixture(refund: 0, remaining: 0);
      (json['hanhDong'] as Map)['dongYQuyetToan'] = true;
      final repo = FakeRepository(json);
      await mount(tester, repo);
      await tester.tap(find.text('Đồng ý quyết toán'));
      await tester.pump();
      expect(repo.writes, 0);
      await tester.tap(find.text('Xác nhận'));
      await tester.pump();
      await tester.pump();
      expect(repo.writes, 1);
    });
    testWidgets(
      'refund view uses real cash label, no fabricated bank or deadline',
      (tester) async {
        await mount(
          tester,
          FakeRepository(
            fixture(acknowledge: true, recorded: 3500000, remaining: 0),
          ),
        );
        expect(find.text('Chi tiết quyết toán'), findsOneWidget);
        expect(find.text('Được hoàn lại'), findsOneWidget);
        expect(find.text('Tôi đã nhận 3.500.000đ'), findsOneWidget);
        expect(find.textContaining('Vietcombank'), findsNothing);
        expect(find.textContaining('24/7'), findsNothing);
        expect(find.text('Đã hoàn thành'), findsNothing);
      },
    );
    testWidgets('refund before Staff recording has no acknowledgement button', (
      tester,
    ) async {
      await mount(tester, FakeRepository(fixture()));
      expect(find.textContaining('Tôi đã nhận'), findsNothing);
    });
    testWidgets(
      'zero branch has no refund0 or customer agreement without capability',
      (tester) async {
        await mount(tester, FakeRepository(fixture(refund: 0, remaining: 0)));
        expect(find.text('Không phát sinh thu/hoàn'), findsOneWidget);
        expect(find.textContaining('Tôi đã nhận'), findsNothing);
        expect(find.text('Đồng ý quyết toán'), findsNothing);
      },
    );
    testWidgets('additional collection keeps disabled gateway honest', (
      tester,
    ) async {
      await mount(
        tester,
        FakeRepository(fixture(collect: 1200000, refund: 0, remaining: 0)),
      );
      expect(find.text('Cần thanh toán thêm'), findsOneWidget);
      expect(find.text('Thanh toán 1.200.000đ'), findsNothing);
    });
    testWidgets('confirmation is explicit and success reloads backend', (
      tester,
    ) async {
      final repo = FakeRepository(
        fixture(acknowledge: true, recorded: 3500000, remaining: 0),
      );
      await mount(tester, repo);
      await tester.tap(find.text('Tôi đã nhận 3.500.000đ'));
      await tester.pump();
      expect(repo.writes, 0);
      expect(find.text('Để sau'), findsOneWidget);
      await tester.tap(find.text('Đã nhận tiền'));
      await tester.pump();
      await tester.pump();
      expect(repo.writes, 1);
      expect(repo.reads, greaterThan(1));
      expect(find.text('Đã hoàn thành'), findsOneWidget);
    });
    testWidgets('opening and postponing refund confirmation never writes', (
      tester,
    ) async {
      final json = fixture(acknowledge: true, recorded: 3500000, remaining: 0);
      final repo = FakeRepository(json);
      await mount(tester, repo);
      await tester.tap(find.text('Tôi đã nhận 3.500.000đ'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận nhận tiền'), findsOneWidget);
      expect(
        find.text('Chỉ xác nhận khi bạn đã nhận đủ tiền hoàn.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text(
            const AppMoneyFormatter().format(
              (json['thanhToan'] as List).single['soTien'] as num,
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(repo.writes, 0);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(repo.writes, 0);
      expect(repo.json['trangThaiHopDong'], 'CHO_HOAN_TRA');
    });
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      testWidgets(
        'refund dialog fits 320px with large text in ${theme.brightness.name}',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = FakeRepository(
            fixture(acknowledge: true, recorded: 3500000, remaining: 0),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2.2)),
                    child: child!,
                  ),
              home: SettlementDetailPage(
                contractId: 'fixture-contract',
                repository: repo,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Tôi đã nhận 3.500.000đ'));
          await tester.tap(find.text('Tôi đã nhận 3.500.000đ'));
          await tester.pumpAndSettle();
          expect(find.text('Xác nhận nhận tiền'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Đã nhận tiền'));
          await tester.pumpAndSettle();
          final bounds = tester.getRect(find.text('Đã nhận tiền'));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(320));
          expect(bounds.bottom, lessThanOrEqualTo(568));
          await tester.tap(find.text('Để sau'));
          await tester.pumpAndSettle();
          expect(repo.writes, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('Schema33 acknowledgement works with feedback disabled', (
      tester,
    ) async {
      final json =
          fixture(acknowledge: true, recorded: 3500000, remaining: 0)
            ..['schemaVersion'] = 3
            ..['phanHoiDuocHoTro'] = false;
      (json['hanhDong'] as Map)['phanHoi'] = false;
      final repo = FakeRepository(json);
      await mount(tester, repo);
      expect(find.text('Gửi phản hồi'), findsNothing);
      await tester.tap(find.text('Tôi đã nhận 3.500.000đ'));
      await tester.pump();
      expect(repo.writes, 0);
      await tester.tap(find.text('Đã nhận tiền'));
      await tester.pump();
      await tester.pump();
      expect(repo.writes, 1);
      expect(repo.reads, greaterThan(1));
      expect(find.text('Đã hoàn thành'), findsOneWidget);
    });
    testWidgets('unknown post result never retries or assumes complete', (
      tester,
    ) async {
      final repo = FakeRepository(
        fixture(acknowledge: true, recorded: 3500000, remaining: 0),
      )..failure = const SettlementFailure('Chưa rõ kết quả', uncertain: true);
      await mount(tester, repo);
      await tester.tap(find.text('Tôi đã nhận 3.500.000đ'));
      await tester.pump();
      await tester.tap(find.text('Đã nhận tiền'));
      await tester.pump();
      await tester.pump();
      expect(repo.writes, 1);
      expect(find.text('Đã hoàn thành'), findsNothing);
      expect(find.textContaining('Tôi đã nhận'), findsNothing);
    });
    testWidgets(
      '320px large text and long actual condition scroll without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final json = fixture();
        (json['nhanTra'] as Map)['thietBi'][0]['tinhTrang'] =
            'Ghi chú kiểm tra rất dài và có căn cứ. ' * 20;
        await tester.pumpWidget(
          MaterialApp(
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
            home: SettlementDetailPage(
              contractId: 'fixture-contract',
              repository: FakeRepository(json),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -1600));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  test(
    'cubit coalesces duplicate reads and rejects stale dialog hash',
    () async {
      final repo = FakeRepository(fixture())..wait = Completer<void>();
      final cubit = ContractDetailCubit(
        contractId: 'fixture-contract',
        repository: repo,
        settlementOnly: true,
      );
      final first = cubit.load();
      final second = cubit.load();
      expect(repo.reads, 1);
      repo.wait!.complete();
      await Future.wait([first, second]);
      await cubit.settlementFeedback(
        'KHONG_DONG_Y',
        expectedHash: 'B' * 64,
        reason: 'test',
      );
      expect(repo.writes, 0);
      await cubit.close();
    },
  );
  test(
    'unknown operation survives page recreation and clears only after Backend evidence',
    () async {
      final repo = FakeRepository(fixture())
        ..failure = const SettlementFailure('timeout', uncertain: true);
      var cubit = ContractDetailCubit(
        contractId: 'fixture-contract',
        repository: repo,
        settlementOnly: true,
      );
      await cubit.load();
      await cubit.settlementFeedback(
        'KHONG_DONG_Y',
        expectedHash: hash,
        reason: 'Synthetic',
      );
      expect(cubit.state.uncertain, isTrue);
      await cubit.close();
      cubit = ContractDetailCubit(
        contractId: 'fixture-contract',
        repository: repo,
        settlementOnly: true,
      );
      await cubit.load();
      expect(cubit.state.uncertain, isTrue);
      expect(repo.writes, 1);
      repo.operationCommitted = true;
      await cubit.load();
      expect(cubit.state.uncertain, isFalse);
      expect(repo.writes, 1);
      await cubit.close();
    },
  );
}
