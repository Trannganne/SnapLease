import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_page.dart';
import 'package:rentcam/features/contract/presentation/tracking/bloc/contract_tracking_state.dart';
import 'package:rentcam/features/contract/presentation/tracking/models/contract_timeline_step.dart';
import 'package:rentcam/features/contract/presentation/tracking/models/contract_tracking_status.dart';
import 'package:rentcam/features/contract/presentation/tracking/widgets/contract_progress_timeline.dart';
import 'package:rentcam/features/contract/presentation/tracking/widgets/contract_status_steps.dart';
import 'package:rentcam/features/contract/presentation/tracking/widgets/current_contract_status_card.dart';
import 'package:rentcam/features/contract/presentation/widgets/contract_handover_card.dart';
import 'package:rentcam/features/contract/presentation/widgets/contract_payment_card.dart';
import 'contract_handover_test.dart' show fixture;

Map<String, dynamic> cancelled({bool signed = false}) =>
    fixture(status: 'DA_HUY')
      ..['ngayKy'] = signed ? '2026-10-02T10:00:00' : null
      ..['chiTiet'] = []
      ..['thanhToan'] = []
      ..['phuLuc'] = [];

Map<String, dynamic> request({String status = 'DA_DUYET'}) => {
  'id': 'YH_TEST',
  'maHopDong': 'HDTEST',
  'trangThai': status,
  'yeuCauLucUtc': '2026-10-03T01:00:00',
  'lyDo': 'Không còn nhu cầu thuê.',
  'xuLyLucUtc': '2026-10-03T02:30:00Z',
  'lyDoXuLy': 'Đã xác minh yêu cầu.',
};

ContractTrackingState tracking(Map<String, dynamic> data) =>
    ContractTrackingState(
      contract: ContractDetailData.fromJson(data, 'HDTEST').contract,
    );

class ReadOnlyRepository extends ContractRepository {
  final Map<String, dynamic> data;
  ReadOnlyRepository(this.data) : super(dio: Dio());
  @override
  Future<Map<String, dynamic>> getContractById(String id) async => data;
  @override
  Future<void> cancelContract(String id) =>
      throw StateError('Display must never cancel a contract');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'canceled before signature keeps creation and terminal cancellation only',
    () {
      final json = cancelled()..['maBamTepPdf'] = 'uploaded-before-otp';
      final state = tracking(json);
      expect(state.status, ContractTrackingStatus.cancelled);
      expect(state.viewData.timelineSteps.map((s) => s.title), [
        'Đã tạo hợp đồng',
        'Hợp đồng đã hủy',
      ]);
      expect(
        state.viewData.timelineSteps.first.timestamp,
        '10:00 • 01/10/2026',
      );
      expect(
        state.viewData.timelineSteps.last.state,
        TimelineStepState.cancelled,
      );
      expect(state.viewData.timelineSteps.last.timestamp, isNull);
      expect(state.viewData.bottomCtaLabel, isEmpty);
      expect(state.viewData.highlightText, isEmpty);
    },
  );

  test(
    'signature is retained, assigned serials alone do not prove handover',
    () {
      final json = cancelled(signed: true)
        ..['chiTiet'] = [
          {
            'maChiTietHopDong': 'CT1',
            'maThietBi': 'TB1',
            'maDongMay': 'DM1',
            'soSerial': 'SERIAL1',
          },
        ];
      final steps = tracking(json).viewData.timelineSteps;
      expect(steps.map((s) => s.title), [
        'Đã tạo hợp đồng',
        'Ký hợp đồng',
        'Hợp đồng đã hủy',
      ]);
      expect(steps[1].timestamp, '10:00 • 02/10/2026');
      expect(steps[1].subtitle, 'Ký điện tử');
      expect(steps[1].state, TimelineStepState.completed);
    },
  );

  test(
    'partial physical events stay factual without claiming settlement or refund',
    () {
      final json = cancelled(signed: true)..['chiTiet'] = fixture()['chiTiet'];
      (json['chiTiet'] as List)[1]['ngayNhanThucTe'] = '2026-10-11T12:00:00';
      final steps = tracking(json).viewData.timelineSteps;
      expect(steps.map((s) => s.title), [
        'Đã tạo hợp đồng',
        'Ký hợp đồng',
        'Đã ghi nhận bàn giao',
        'Đã nhận lại thiết bị',
        'Hợp đồng đã hủy',
      ]);
      expect(steps[2].subtitle, 'Đã bàn giao 1 thiết bị');
      expect(steps[2].timestamp, '09:15 • 10/10/2026');
      expect(steps[3].subtitle, 'Đã nhận lại 1 thiết bị');
      expect(steps[3].timestamp, '12:00 • 11/10/2026');
      final text = steps.map((s) => '${s.title} ${s.subtitle}').join('\n');
      for (final unsupported in [
        'Theo trạng thái hợp đồng',
        'Chưa có đủ ngày giao thực tế',
        'Hoàn tất',
        'quyết toán',
        'hoàn cọc',
        'Đã thanh toán',
      ]) {
        expect(text, isNot(contains(unsupported)));
      }
      expect(steps.where((s) => s.state == TimelineStepState.pending), isEmpty);
    },
  );

  test(
    'request time is separate from effective cancellation and both UTC forms agree',
    () {
      final withZ = tracking(cancelled()..['yeuCauHuy'] = [request()]);
      final withoutZ = tracking(
        cancelled()
          ..['yeuCauHuy'] = [
            {...request(), 'xuLyLucUtc': '2026-10-03T02:30:00'},
          ],
      );
      final closing = withZ.viewData.timelineSteps.last;
      expect(
        closing.timestamp,
        'Thời gian hủy: 09:30 • 03/10/2026 (giờ Việt Nam)',
      );
      expect(closing.timestamp, withoutZ.viewData.timelineSteps.last.timestamp);
      expect(closing.subtitle, contains('Gửi yêu cầu: 08:00 • 03/10/2026'));
      expect(closing.subtitle, contains('Lý do hủy: Đã xác minh yêu cầu.'));
      expect(
        closing.subtitle,
        contains('Lý do yêu cầu hủy: Không còn nhu cầu thuê.'),
      );
      expect(
        withZ.contract.cancellation!.effectiveAtUtc,
        DateTime.utc(2026, 10, 3, 2, 30),
      );
    },
  );

  test(
    'missing or malformed effective date never falls back to request time or now',
    () {
      for (final date in [null, '', 'not-a-date']) {
        final json =
            cancelled()
              ..['yeuCauHuy'] = [
                {
                  ...request(),
                  'xuLyLucUtc': date,
                  'lyDo': null,
                  'lyDoXuLy': '  ',
                },
              ];
        final closing = tracking(json).viewData.timelineSteps.last;
        expect(closing.timestamp, isNull);
        expect(closing.subtitle, startsWith('Gửi yêu cầu:'));
        expect(closing.subtitle, isNot(contains('Lý do')));
      }
      final closing = tracking(cancelled()).viewData.timelineSteps.last;
      expect(closing.subtitle, isEmpty);
      expect(closing.timestamp, isNull);
    },
  );

  test('approved request metadata does not terminate an active contract', () {
    final json = fixture(status: 'DA_KY')..['yeuCauHuy'] = [request()];
    final state = tracking(json);
    expect(state.status, ContractTrackingStatus.signed);
    expect(state.contract.cancellation, isNull);
    expect(state.viewData.timelineSteps.length, 6);
    expect(
      state.viewData.timelineSteps.any(
        (s) => s.state == TimelineStepState.cancelled,
      ),
      isFalse,
    );
  });

  for (final requestStatus in ['CHO_XAC_NHAN', 'TU_CHOI']) {
    test(
      '$requestStatus cancellation request leaves the active workflow unchanged',
      () {
        final json = fixture(status: 'DANG_THUE')
          ..['yeuCauHuy'] = [request(status: requestStatus)];
        final state = tracking(json);
        expect(state.status, ContractTrackingStatus.renting);
        expect(state.contract.cancellation, isNull);
        expect(state.viewData.timelineSteps.length, 6);
        expect(state.viewData.timelineSteps[3].state, TimelineStepState.active);
        expect(state.viewData.bottomCtaLabel, 'Yêu cầu gia hạn thuê');
        expect(
          state.viewData.timelineSteps.map((s) => s.title),
          isNot(contains('Hợp đồng đã hủy')),
        );
      },
    );
    test(
      '$requestStatus reason/time is not attributed to a different actual cancellation',
      () {
        final json =
            cancelled()..['yeuCauHuy'] = [request(status: requestStatus)];
        final closing = tracking(json).viewData.timelineSteps.last;
        expect(closing.subtitle, isEmpty);
        expect(closing.timestamp, isNull);
      },
    );
  }

  test(
    'latest approved request is selected without mixing rejected history',
    () {
      final state = tracking(
        cancelled()
          ..['yeuCauHuy'] = [
            {
              ...request(),
              'xuLyLucUtc': '2026-10-02T02:00:00Z',
              'lyDoXuLy': 'Cũ',
            },
            request(),
            {
              ...request(status: 'TU_CHOI'),
              'xuLyLucUtc': '2026-10-04T02:00:00Z',
              'lyDoXuLy': 'Không phải lý do hủy',
            },
          ],
      );
      expect(
        state.viewData.timelineSteps.last.subtitle,
        contains('Đã xác minh yêu cầu.'),
      );
      expect(
        state.viewData.timelineSteps.last.subtitle,
        isNot(contains('Không phải lý do hủy')),
      );
    },
  );

  for (final status in ['DANG_THUE', 'HOAN_THANH']) {
    test('$status retains existing timeline and current progress', () {
      final state = tracking(fixture(status: status));
      expect(state.viewData.timelineSteps.length, 6);
      expect(state.viewData.timelineSteps[2].timestamp, isNull);
      expect(state.viewData.timelineSteps[3].title, 'Đang thuê');
      expect(state.viewData.timelineSteps.last.title, 'Hoàn tất hợp đồng');
      expect(
        state.viewData.timelineSteps[status == 'DANG_THUE' ? 3 : 5].state,
        status == 'HOAN_THANH'
            ? TimelineStepState.completed
            : TimelineStepState.active,
      );
      expect(
        state.viewData.timelineSteps.any(
          (s) => s.state == TimelineStepState.cancelled,
        ),
        isFalse,
      );
    });
  }

  test(
    'optional owner-authorized history enriches only the matching approved request',
    () async {
      final data =
          cancelled()
            ..['yeuCauHuy'] = [
              request()
                ..remove('xuLyLucUtc')
                ..remove('lyDoXuLy'),
            ];
      final calls = <String>[];
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (o, h) {
                  calls.add('${o.method} ${o.path}');
                  h.resolve(
                    Response(
                      requestOptions: o,
                      statusCode: 200,
                      data:
                          o.path.endsWith('/huy-truoc-ban-giao')
                              ? {
                                'yeuCau': [request()],
                              }
                              : data,
                    ),
                  );
                },
              ),
            );
      addTearDown(dio.close);
      final result = await ContractRepository(
        dio: dio,
      ).getContractById('HDTEST');
      expect(calls, [
        'GET /api/hop-dong/HDTEST',
        'GET /api/hop-dong/HDTEST/huy-truoc-ban-giao',
      ]);
      expect(
        tracking(result).viewData.timelineSteps.last.timestamp,
        contains('09:30'),
      );
      expect(data['yeuCauHuy'].first['xuLyLucUtc'], isNull);
      expect(result['thanhToan'], data['thanhToan']);
    },
  );

  for (final badHistory in [
    {
      'yeuCau': [
        {...request(), 'maHopDong': 'OTHER'},
      ],
    },
    {
      'yeuCau': [
        {...request(), 'id': 'OTHER'},
      ],
    },
    {
      'yeuCau': [request(status: 'TU_CHOI')],
    },
    {
      'yeuCau': [request(), request()],
    },
    {'yeuCau': 'bad-response'},
    'offline',
  ]) {
    test(
      'optional mismatched, ambiguous or offline history preserves known facts: $badHistory',
      () async {
        final data =
            cancelled()
              ..['yeuCauHuy'] = [
                request()
                  ..remove('xuLyLucUtc')
                  ..remove('lyDoXuLy'),
              ];
        final dio =
            Dio()
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (o, h) {
                    expect(o.method, 'GET');
                    if (!o.path.endsWith('/huy-truoc-ban-giao')) {
                      h.resolve(
                        Response(
                          requestOptions: o,
                          statusCode: 200,
                          data: data,
                        ),
                      );
                    } else if (badHistory == 'offline') {
                      h.reject(
                        DioException(
                          requestOptions: o,
                          type: DioExceptionType.connectionTimeout,
                        ),
                      );
                    } else {
                      h.resolve(
                        Response(
                          requestOptions: o,
                          statusCode: 200,
                          data: badHistory,
                        ),
                      );
                    }
                  },
                ),
              );
        addTearDown(dio.close);
        final state = tracking(
          await ContractRepository(dio: dio).getContractById('HDTEST'),
        );
        expect(state.viewData.timelineSteps.last.timestamp, isNull);
        expect(
          state.viewData.timelineSteps.last.subtitle,
          contains('Lý do yêu cầu hủy: Không còn nhu cầu thuê.'),
        );
        expect(
          state.viewData.timelineSteps.last.subtitle,
          isNot(contains('Lý do hủy:')),
        );
      },
    );
  }

  test(
    'active, direct-cancelled and already enriched detail need no extra GET',
    () async {
      final rows = [
        fixture(status: 'DANG_THUE')..['yeuCauHuy'] = [request()],
        cancelled(),
        cancelled()..['yeuCauHuy'] = [request()],
      ];
      for (final row in rows) {
        final calls = <String>[];
        final dio =
            Dio()
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (o, h) {
                    calls.add('${o.method} ${o.path}');
                    h.resolve(
                      Response(requestOptions: o, statusCode: 200, data: row),
                    );
                  },
                ),
              );
        await ContractRepository(dio: dio).getContractById('HDTEST');
        expect(calls, ['GET /api/hop-dong/HDTEST']);
        dio.close();
      }
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'terminal cancellation, long reason and no future chips at 320px/2x, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final json = cancelled(signed: true)
          ..['yeuCauHuy'] = [
            {
              ...request(),
              'lyDoXuLy': List.filled(
                30,
                'Lý do hủy dài để kiểm tra màn hình hẹp.',
              ).join(' '),
            },
          ];
        final data = tracking(json).viewData;
        final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    ContractStatusSteps(status: data.status),
                    CurrentContractStatusCard(viewData: data),
                    ContractProgressTimeline(steps: data.timelineSteps),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hợp đồng đã hủy'), findsOneWidget);
        expect(find.text('Chờ bàn giao'), findsNothing);
        expect(find.text('Đang thuê'), findsNothing);
        expect(find.text('Chờ hoàn trả'), findsNothing);
        expect(find.text('Hoàn tất'), findsNothing);
        expect(find.byIcon(Icons.event_available), findsNothing);
        final terminal = find.descendant(
          of: find.byType(ContractProgressTimeline),
          matching: find.byIcon(Icons.cancel_outlined),
        );
        expect(tester.widget<Icon>(terminal).color, theme.colorScheme.error);
        final iconColumn = tester.widget<Column>(
          find.ancestor(of: terminal, matching: find.byType(Column)).first,
        );
        expect(
          iconColumn.children.length,
          1,
          reason: 'No connector below the terminal cancellation',
        );
        expect(
          find.descendant(
            of: find.byType(ContractProgressTimeline),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsNWidgets(2),
        );
        final position =
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
        for (double y = 0; y < position.maxScrollExtent; y += 250) {
          position.jumpTo(y);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'canceled detail blocks stale renewal/sign actions but preserves documents and payment history',
    (tester) async {
      final json =
          cancelled(signed: true)
            ..['coTheYeuCauGiaHan'] = true
            ..['maBamTepPdf'] = 'existing-signed-document'
            ..['yeuCauHuy'] = [request()]
            ..['phuLuc'] = [
              {
                'maPhuLuc': 'PL_TEST',
                'trangThai': 'CHO_KY',
                'hanKyUtc': '2099-10-23T04:00:00Z',
              },
            ]
            ..['hoanTienHuy'] = [
              {
                'loaiThanhToan': 'HOAN_COC',
                'soTien': 3000000,
                'trangThai': 'CHO_XAC_NHAN',
              },
            ];
      await tester.pumpWidget(
        MaterialApp(
          home: ContractPage(
            contractId: 'HDTEST',
            action: 'renewal',
            repository: ReadOnlyRepository(json),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContractRenewalPage), findsNothing);
      expect(
        find.byKey(const ValueKey('contract-primary-action')),
        findsNothing,
      );
      expect(find.text('Xem và ký phụ lục'), findsNothing);
      expect(find.text('Yêu cầu gia hạn thuê'), findsNothing);
      expect(find.byType(ContractHandoverCard), findsOneWidget);
      expect(find.byType(ContractPaymentCard), findsOneWidget);
      expect(find.textContaining('Đã thanh toán cọc'), findsNothing);
      expect(find.textContaining('Đã hoàn cọc'), findsNothing);
      expect(find.textContaining('Đã xác nhận hoàn thực tế'), findsNothing);
      expect(
        find.textContaining('Đang theo dõi, chưa xác nhận hoàn'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'cancellation status never manufactures successful financial records',
    () {
      final json =
          cancelled()
            ..['thanhToan'] = [
              {
                'maThanhToan': 'TT_TEST',
                'loaiThanhToan': 'HOAN_COC',
                'trangThai': 'CHO_XAC_NHAN',
                'soTien': 3000000,
              },
            ];
      final state = tracking(json);
      expect(state.contract.payments.successfulDeposits, isEmpty);
      expect(state.contract.payments.receipts.single.status, 'CHO_XAC_NHAN');
      expect(state.contract.cancellationRefunds, isEmpty);
      expect(jsonEncode(state.contract.cancellations), '[]');
    },
  );
}
