import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rentcam/core/widgets/app_availability_calendar.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/features/contract/data/contract_list_repository.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/domain/models/extension_models.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_cubit.dart';
import 'contract_handover_test.dart' show fixture;

class RenewalRepository extends ContractRepository {
  Map<String, dynamic> json = {
    ...fixture(status: 'DANG_THUE'),
    'coTheYeuCauGiaHan': true,
    'thoiGianTraDuKien': '2026-11-20T09:15:30',
    'phuLuc': <Map<String, dynamic>>[],
  };
  final previews = <Completer<ExtensionQuote>>[];
  final dates = <DateTime>[];
  Completer<Map<String, dynamic>>? post;
  int posts = 0, reads = 0;
  @override
  Future<Map<String, dynamic>> getContractById(String id) async {
    reads++;
    return json;
  }

  @override
  Future<ExtensionQuote> previewExtension(String id, DateTime date) {
    dates.add(date);
    final result = Completer<ExtensionQuote>();
    previews.add(result);
    return result.future;
  }

  @override
  Future<Map<String, dynamic>> requestExtension(
    String id,
    DateTime date,
    String reason,
  ) {
    posts++;
    return (post = Completer<Map<String, dynamic>>()).future;
  }

  ExtensionQuote quote(int index, {bool available = true}) => ExtensionQuote(
    available,
    available ? null : 'Trùng lịch',
    DateTime.parse(json['thoiGianTraDuKien']),
    dates[index],
    3,
    123456,
  );
  Map<String, dynamic> supplement(
    DateTime date, {
    String status = 'CHO_XAC_NHAN',
  }) => {
    'maPhuLuc': 'PLTEST',
    'maHopDong': 'HDTEST',
    'trangThai': status,
    'thoiHanTraMoi': date.toIso8601String(),
    'lyDoGiaHan': 'Cần thêm thời gian',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RenewalRepository repository;
  late ContractRenewalCubit cubit;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = RenewalRepository();
    cubit = ContractRenewalCubit('HDTEST', repository);
    await cubit.load();
  });
  tearDown(() => cubit.close());

  test(
    'invalid date, whole interval conflict, and late responses never enable stale quote',
    () async {
      await cubit.selectDate(DateTime(2026, 11, 20));
      expect(repository.previews, isEmpty);
      expect(cubit.state.canSubmit, isFalse);
      final first = cubit.selectDate(DateTime(2026, 11, 21));
      final second = cubit.selectDate(DateTime(2026, 11, 23));
      expect(cubit.state.quote, isNull);
      repository.previews[1].complete(repository.quote(1));
      await second;
      repository.previews[0].complete(repository.quote(0, available: false));
      await first;
      expect(cubit.state.selected, DateTime(2026, 11, 23, 9, 15, 30));
      expect(cubit.state.quote!.cost, 123456);
      expect(cubit.state.canSubmit, isTrue);
      expect(
        repository.dates.last.toIso8601String(),
        '2026-11-23T09:15:30.000',
      );
      final conflict = cubit.selectDate(DateTime(2026, 11, 25));
      expect(cubit.state.canSubmit, isFalse);
      repository.previews[2].complete(repository.quote(2, available: false));
      await conflict;
      expect(cubit.state.canSubmit, isFalse);
      expect(cubit.state.message, 'Trùng lịch');
    },
  );

  Future<void> validPreview() async {
    final future = cubit.selectDate(DateTime(2026, 11, 23));
    repository.previews.last.complete(
      repository.quote(repository.previews.length - 1),
    );
    await future;
  }

  test(
    'submit once, reload pending; due changes only with approved supplement',
    () async {
      await validPreview();
      final date = cubit.state.selected!;
      final due = cubit.state.currentReturn;
      final sending = cubit.submit('Cần thêm thời gian');
      await Future<void>.delayed(Duration.zero);
      await cubit.submit('Cần thêm thời gian');
      expect(repository.posts, 1);
      repository.json['phuLuc'] = [repository.supplement(date)];
      repository.post!.complete(repository.supplement(date));
      await sending;
      expect(repository.reads, 2);
      expect(cubit.state.pending, isNotNull);
      expect(cubit.state.currentReturn, due);
      expect(cubit.state.contract!.returnDate, due);
      expect(cubit.state.contract!.proposedReturnDate, date);
      expect(cubit.state.canSubmit, isFalse);
      repository.json['phuLuc'] = [
        repository.supplement(date, status: 'DA_XAC_NHAN'),
      ];
      await cubit.load();
      expect(cubit.state.currentReturn, date);
      expect(cubit.state.contract!.effectiveReturnDate, date);
      expect(cubit.state.contract!.returnDate, due);
    },
  );

  test(
    'timeout stays unresolved across reopening; matching server supplement resolves it without POST retry',
    () async {
      await validPreview();
      final date = cubit.state.selected!;
      final sending = cubit.submit('Cần thêm thời gian');
      await Future<void>.delayed(Duration.zero);
      repository.post!.completeError(
        const ExtensionFailure('Timeout', uncertain: true),
      );
      await sending;
      expect(cubit.state.uncertain, isTrue);
      expect(cubit.state.canSelect, isFalse);
      final reopened = ContractRenewalCubit('HDTEST', repository);
      await reopened.load();
      expect(reopened.state.uncertain, isTrue);
      repository.json['phuLuc'] = [repository.supplement(date)];
      await reopened.load();
      expect(reopened.state.uncertain, isFalse);
      expect(reopened.state.pending, isNotNull);
      expect(repository.posts, 1);
      await reopened.close();
    },
  );

  test(
    'definite API failure refreshes and clears quote; invalid reason never posts',
    () async {
      await validPreview();
      await cubit.submit(' ');
      expect(repository.posts, 0);
      final sending = cubit.submit('Cần thêm thời gian');
      await Future<void>.delayed(Duration.zero);
      repository.post!.completeError(const ExtensionFailure('Không đủ quyền'));
      await sending;
      expect(cubit.state.message, contains('Không đủ quyền'));
      expect(cubit.state.quote, isNull);
      expect(cubit.state.uncertain, isFalse);
    },
  );

  test(
    'overdue is not silently forbidden beyond backend status rules',
    () async {
      repository.json['thoiGianTraDuKien'] = '2020-01-01T09:15:30';
      await cubit.load();
      final future = cubit.selectDate(DateTime(2020, 1, 3));
      repository.previews.last.complete(repository.quote(0, available: false));
      await future;
      expect(cubit.state.canSubmit, isFalse);
      repository.json['trangThai'] = 'CHO_HOAN_TRA';
      await cubit.load();
      expect(cubit.state.canSelect, isFalse);
    },
  );

  test(
    'repository sends exact DTO and maps conflict / forbidden / ambiguous POST',
    () async {
      final dio = Dio();
      final api = ContractRepository(dio: dio);
      int mode = 0;
      final date = DateTime(2026, 11, 23, 9, 15, 30);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'GET') {
              expect(
                options.queryParameters['thoiHanTraMoi'],
                date.toIso8601String(),
              );
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 409,
                    data: {
                      'coTheGiaHan': false,
                      'lyDo': 'Trùng lịch',
                      'thoiHanTraHienTai': '2026-11-20T09:15:30',
                      'thoiHanTraMoi': date.toIso8601String(),
                      'soNgayGiaHan': 0,
                      'chiPhiDuKien': 0,
                    },
                  ),
                ),
              );
              return;
            }
            expect(options.path, '/api/hop-dong/HDTEST/yeu-cau-gia-han');
            expect(options.data, {
              'thoiHanTraMoi': date.toIso8601String(),
              'lyDoGiaHan': 'Lý do',
              'ghiChu': null,
            });
            if (mode == 0) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: repository.supplement(date),
                ),
              );
            } else {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type:
                      mode == 2
                          ? DioExceptionType.receiveTimeout
                          : DioExceptionType.badResponse,
                  response:
                      mode == 2
                          ? null
                          : Response(requestOptions: options, statusCode: 403),
                ),
              );
            }
          },
        ),
      );
      expect((await api.previewExtension('HDTEST', date)).available, isFalse);
      await api.requestExtension('HDTEST', date, ' Lý do ');
      mode = 1;
      await expectLater(
        api.requestExtension('HDTEST', date, 'Lý do'),
        throwsA(
          isA<ExtensionFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            false,
          ),
        ),
      );
      mode = 2;
      await expectLater(
        api.requestExtension('HDTEST', date, 'Lý do'),
        throwsA(
          isA<ExtensionFailure>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
    },
  );

  testWidgets(
    'shared calendar fixes start, disables boundary, selects only new return without availability requests',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await initializeDateFormatting('vi_VN');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAvailabilityCalendar(
              currentPickup: DateTime(2026, 11, 20),
              branchId: null,
              deviceId: '',
              quantity: 1,
              fixedPickup: true,
            ),
          ),
        ),
      );
      final calendar = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      expect(calendar.enabledDayPredicate!(DateTime(2026, 11, 20)), isFalse);
      expect(calendar.enabledDayPredicate!(DateTime(2026, 11, 21)), isTrue);
      calendar.onDaySelected!(DateTime(2026, 11, 23), DateTime(2026, 11, 23));
      await tester.pump();
      final selected = tester.widget<TableCalendar>(
        find.byWidgetPredicate((w) => w is TableCalendar),
      );
      expect(selected.rangeStartDay, DateTime(2026, 11, 20));
      expect(selected.rangeEndDay, DateTime(2026, 11, 23));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'booking calendar retains monthly marks and blocks a range crossing an unavailable interior day',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await initializeDateFormatting('vi_VN');
      final now = DateTime.now();
      final start = DateTime(now.year, now.month + 1, 5);
      final blocked = DateTime(now.year, now.month + 1, 6);
      final end = DateTime(now.year, now.month + 1, 7);
      final dio = ApiClient.instance;
      var requests = 0;
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          expect(options.path, '/api/lich-trong/thang');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'ngayList': [
                  for (var day = 1; day <= 28; day++)
                    {
                      'ngay':
                          DateTime(
                            start.year,
                            start.month,
                            day,
                          ).toIso8601String(),
                      'trangThai': day == 6 ? 'DO' : 'XANH',
                    },
                ],
              },
            ),
          );
        },
      );
      dio.interceptors.add(interceptor);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppAvailabilityCalendar(
                currentPickup: start,
                currentReturn: end,
                branchId: 'CNTEST',
                deviceId: 'DMTEST',
                quantity: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final calendar = tester.widget<TableCalendar>(
          find.byWidgetPredicate((w) => w is TableCalendar),
        );
        expect(calendar.rangeSelectionMode, RangeSelectionMode.toggledOn);
        expect(requests, 1);
        expect(
          calendar.calendarBuilders.markerBuilder!(
            tester.element(find.byWidgetPredicate((w) => w is TableCalendar)),
            blocked,
            [],
          ),
          isA<Positioned>(),
        );
        expect(
          find.text(
            'Khoảng thời gian đã chọn có ngày không đủ máy. Vui lòng điều chỉnh.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        dio.interceptors.remove(interceptor);
      }
    },
  );

  test('pending supplement never changes original or effective due', () {
    final due = DateTime.parse(repository.json['thoiGianTraDuKien']);
    repository.json['phuLuc'] = [
      repository.supplement(due.add(const Duration(days: 3))),
    ];
    final model =
        ContractDetailData.fromJson(repository.json, 'HDTEST').contract;
    expect(model.effectiveReturnDate, due);
    expect(model.proposedReturnDate, due.add(const Duration(days: 3)));
  });

  test(
    'list refresh uses supplements and never treats pending date as effective',
    () async {
      final dio = Dio();
      final due = DateTime.parse(repository.json['thoiGianTraDuKien']);
      final proposed = due.add(const Duration(days: 3));
      repository.json['phuLuc'] = [repository.supplement(proposed)];
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data:
                    options.path.endsWith('cua-toi')
                        ? [repository.json]
                        : repository.json,
              ),
            );
          },
        ),
      );
      final list = ContractListRepository(dio: dio);
      final pending = (await list.getContracts()).single;
      expect(pending.returnDate, due);
      expect(pending.statusAlertMessage, contains('23/11/2026'));
      repository.json['phuLuc'] = [
        repository.supplement(proposed, status: 'DA_XAC_NHAN'),
      ];
      final approved = (await list.getContracts()).single;
      expect(approved.returnDate, proposed);
      expect(approved.statusAlertMessage, isNull);
      expect(paths, [
        '/api/hop-dong/cua-toi',
        '/api/hop-dong/HDTEST',
        '/api/hop-dong/cua-toi',
        '/api/hop-dong/HDTEST',
      ]);
    },
  );

  test(
    'default ApiClient attaches stored bearer to extension request',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'test-only-token',
      });
      final dio = ApiClient.instance;
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.headers['Authorization'], 'Bearer test-only-token');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 201,
              data: repository.supplement(DateTime(2026, 11, 23)),
            ),
          );
        },
      );
      dio.interceptors.add(interceptor);
      try {
        await ContractRepository().requestExtension(
          'HDTEST',
          DateTime(2026, 11, 23),
          'Lý do',
        );
      } finally {
        dio.interceptors.remove(interceptor);
      }
    },
  );
}
