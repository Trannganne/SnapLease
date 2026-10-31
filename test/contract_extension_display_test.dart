import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/navigation/app_route_observer.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/contract_list_repository.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/domain/models/contract_summary_model.dart';
import 'package:rentcam/features/contract/domain/models/extension_models.dart';
import 'package:rentcam/features/contract/presentation/list/bloc/contract_list_bloc.dart';
import 'package:rentcam/features/contract/presentation/list/bloc/contract_list_event.dart';
import 'package:rentcam/features/contract/presentation/list/contract_list_page.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_cubit.dart';
import 'package:rentcam/features/contract/presentation/renewal/contract_renewal_page.dart';
import 'package:rentcam/features/notification/data/push_service.dart';
import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/notification/presentation/notification_detail_page.dart';
import 'contract_handover_test.dart' show fixture;

const approvedContract = 'HDD41E30EC41764CB68A';
const rejectedContract = 'HDDC591CC7C3D74D9C88';
const approvedAppendix = 'PL67B7C8DE868F4D01BD';
const rejectedAppendix = 'PLB21E062D3B7844C7B1';
const rejection =
    'Thiết bị cần bảo trì sau khi kết thúc thời gian thuê hiện tại nên không thể đáp ứng khoảng gia hạn.';

Map<String, dynamic> appendix(
  String status, {
  String id = approvedAppendix,
  String contract = approvedContract,
}) => {
  'maPhuLuc': id,
  'maHopDong': contract,
  'trangThai': status,
  'ngayLap': '2026-10-23T01:50:19Z',
  'hieuLucTu': '2026-10-25T08:00:00',
  'thoiHanTraMoi': '2026-10-26T08:00:00',
  'chiPhiPhatSinh': 500000,
  'tienCocBoSung': 0,
  'hanXuLyUtc': '2026-10-23T05:50:19Z',
  'hanKyUtc': status == 'CHO_KY' ? '2026-10-23T04:03:35.3303416Z' : null,
  'ghiChu': status == 'TU_CHOI' ? rejection : null,
};

Map<String, dynamic> detail(
  String status, {
  String id = approvedContract,
  String pid = approvedAppendix,
}) => {
  ...fixture(status: 'DANG_THUE'),
  'maHopDong': id,
  'thoiGianTraDuKien': '2026-10-25T08:00:00',
  'thoiHanTraHieuLuc': '2026-10-25T08:00:00',
  'thoiGianServer': '2026-10-23T02:25:34Z',
  'coTheYeuCauGiaHan': true,
  'phuLuc': [appendix(status, id: pid, contract: id)],
};

class DisplayRepository extends ContractRepository {
  Map<String, dynamic> json = detail('CHO_KY');
  int reads = 0, writes = 0, pdfReads = 0;
  final queue = <Completer<Map<String, dynamic>>>[];
  bool queued = false;
  @override
  Future<Map<String, dynamic>> getContractById(String id) async {
    reads++;
    if (queued) {
      final next = Completer<Map<String, dynamic>>();
      queue.add(next);
      return next.future;
    }
    return jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> requestExtension(
    String id,
    DateTime date,
    String reason,
  ) async {
    writes++;
    throw StateError('Display must never submit a request');
  }

  @override
  Future<Uint8List> loadAppendixPdf(String id) async {
    pdfReads++;
    throw StateError('Not expected during display or refresh');
  }
}

class ListRepository extends ContractListRepository {
  int reads = 0;
  List<ContractSummaryModel> rows = [];
  final pending = <Completer<List<ContractSummaryModel>>>[];
  bool queued = false;
  @override
  Future<List<ContractSummaryModel>> getContracts() async {
    reads++;
    if (!queued) return rows;
    final next = Completer<List<ContractSummaryModel>>();
    pending.add(next);
    return next.future;
  }
}

ContractSummaryModel summary(String id) => ContractSummaryModel(
  id: id,
  status: ContractStatus.active,
  originalStatus: 'DANG_THUE',
  imagePath: '',
  deviceName: 'Canon EOS R6',
  packageInfo: 'Thuê máy',
  pickupDate: DateTime(2026, 10, 23),
  returnDate: DateTime(2026, 10, 25, 8),
  branchName: 'Quận 1',
  totalAmount: 1000000,
);

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'list and detail preserve distinct CHO_KY/TU_CHOI and original due',
    () async {
      final dio = Dio();
      final rows = {
        approvedContract: detail('CHO_KY'),
        rejectedContract: detail(
          'TU_CHOI',
          id: rejectedContract,
          pid: rejectedAppendix,
        ),
      };
      final calls = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add('${o.method} ${o.path}');
            expect(o.method, 'GET');
            final data =
                o.path.endsWith('cua-toi')
                    ? rows.values.map((r) => {...r}..remove('phuLuc')).toList()
                    : rows[o.path.split('/').last];
            h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
          },
        ),
      );
      final result = await ContractListRepository(dio: dio).getContracts();
      expect(result[0].extension!.id, approvedAppendix);
      expect(
        result[0].statusAlertMessage,
        contains('Gia hạn được duyệt – Chờ ký phụ lục'),
      );
      expect(result[0].statusAlertMessage, contains('23/10/2026 11:03'));
      expect(
        result[0].statusAlertMessage,
        isNot(contains('Gia hạn chờ duyệt')),
      );
      expect(result[1].extension!.id, rejectedAppendix);
      expect(result[1].statusAlertMessage, contains('Gia hạn bị từ chối'));
      expect(result[1].statusAlertMessage, contains(rejection));
      expect(
        result.every((c) => c.returnDate == DateTime(2026, 10, 25, 8)),
        isTrue,
      );
      expect(calls.length, 3);
      dio.close();
    },
  );

  test(
    'latest appendix uses requested timestamp, not incidental array order',
    () {
      final rows = [
        {...appendix('CHO_KY'), 'ngayLap': '2026-10-23T02:00:00Z'},
        {...appendix('TU_CHOI', id: 'OLD'), 'ngayLap': '2026-10-22T02:00:00Z'},
        {...appendix('TU_CHOI', id: 'LEGACY')}..remove('ngayLap'),
      ];
      expect(ExtensionSummary.latestRow(rows)!['maPhuLuc'], approvedAppendix);
    },
  );

  test('UTC deadline is correct with Z and with omitted UTC suffix', () {
    final p = appendix('CHO_KY');
    final withZ = ExtensionSummary.fromJson(p);
    final withoutZ = ExtensionSummary.fromJson({
      ...p,
      'hanKyUtc': '2026-10-23T04:03:35.3303416',
    });
    expect(withZ.signingDeadlineUtc, withoutZ.signingDeadlineUtc);
    expect(withZ.canSignAt(DateTime.utc(2026, 10, 23, 4, 3, 35)), isTrue);
    expect(withZ.canSignAt(DateTime.utc(2026, 10, 23, 4, 4)), isFalse);
  });

  test(
    'refresh updates pending -> approved -> rejected, never effective due or POST',
    () async {
      final repo = DisplayRepository()..json = detail('CHO_XAC_NHAN');
      final cubit = ContractRenewalCubit(approvedContract, repo);
      await cubit.load();
      expect(cubit.state.selectedAppendix!['trangThai'], 'CHO_XAC_NHAN');
      repo.json = detail('CHO_KY');
      await cubit.load();
      expect(cubit.state.canSign, isTrue);
      repo.json = detail('TU_CHOI');
      await cubit.load();
      expect(cubit.state.canSign, isFalse);
      expect(cubit.state.selectedAppendix!['ghiChu'], rejection);
      expect(cubit.state.currentReturn, DateTime(2026, 10, 25, 8));
      expect(repo.writes, 0);
      await cubit.close();
    },
  );

  test(
    'explicit rejected ID cannot open or sign a later approved appendix',
    () async {
      final repo = DisplayRepository();
      repo.json['phuLuc'] = [
        appendix('TU_CHOI', id: rejectedAppendix),
        appendix('CHO_KY'),
      ];
      final cubit = ContractRenewalCubit(
        approvedContract,
        repo,
        appendixId: rejectedAppendix,
      );
      await cubit.load();
      expect(cubit.state.selectedAppendix!['maPhuLuc'], rejectedAppendix);
      expect(cubit.state.canSign, isFalse);
      await cubit.close();
      final missing = ContractRenewalCubit(
        approvedContract,
        repo,
        appendixId: 'MISSING',
      );
      await missing.load();
      expect(missing.state.selectedAppendix, isNull);
      expect(missing.state.canSign, isFalse);
      expect(missing.state.message, contains('Không tìm thấy'));
      await missing.close();
    },
  );

  test(
    'push during a read queues fresh GET and does not lose the updated decision',
    () async {
      final repo = DisplayRepository()..queued = true;
      final cubit = ContractRenewalCubit(approvedContract, repo);
      final loading = cubit.load();
      await flush();
      PushService.instance.updates.add(null);
      await flush();
      repo.queue[0].complete(detail('CHO_XAC_NHAN'));
      await flush();
      expect(repo.queue.length, 2);
      repo.queue[1].complete(detail('CHO_KY'));
      await loading;
      expect(cubit.state.selectedAppendix!['trangThai'], 'CHO_KY');
      expect(repo.writes, 0);
      await cubit.close();
    },
  );

  test(
    'list ignores stale response and refreshes on existing push update stream',
    () async {
      final repo = ListRepository()..queued = true;
      final bloc = ContractListBloc(repository: repo)..add(LoadContracts());
      await flush();
      PushService.instance.updates.add(null);
      await flush();
      expect(repo.pending.length, 2);
      repo.pending[1].complete([summary('NEW')]);
      await flush();
      repo.pending[0].complete([summary('OLD')]);
      await flush();
      expect(bloc.state.allContracts.single.id, 'NEW');
      await bloc.close();
    },
  );

  test(
    'notification roundtrip keeps event and only resolves unambiguous appendix',
    () {
      final notice = NotificationItemModel.fromJson({
        'maThongBao': 'NOTICE',
        'loai': 'GIA_HAN',
        'eventCode': 'EXTENSION_CHO_KY',
        'targetType': 'HOP_DONG',
        'targetId': approvedContract,
        'daDoc': true,
        'thoiGianGui': '2026-10-23T02:03:35Z',
      });
      expect(
        NotificationItemModel.fromJson(notice.toJson()).eventCode,
        'EXTENSION_CHO_KY',
      );
      expect(notice.resolveAppendixId([appendix('CHO_KY')]), approvedAppendix);
      expect(
        notice.resolveAppendixId([
          appendix('CHO_KY'),
          appendix('TU_CHOI', id: 'OLD'),
        ]),
        isNull,
      );
      expect(
        notice.resolveAppendixId([appendix('CHO_KY', contract: 'OTHER')]),
        isNull,
      );
      final explicit = NotificationItemModel.fromJson({
        ...notice.toJson(),
        'maPhuLuc': 'OLD',
      });
      expect(
        explicit.resolveAppendixId([
          appendix('CHO_KY'),
          appendix('TU_CHOI', id: 'OLD'),
        ]),
        'OLD',
      );
    },
  );

  testWidgets(
    'approved page shows exact appendix/deadline; rejected page shows reason',
    (tester) async {
      final repo = DisplayRepository();
      final model =
          ContractDetailData.fromJson(repo.json, approvedContract).contract;
      await tester.pumpWidget(
        MaterialApp(
          home: ContractRenewalPage(
            contract: model,
            repository: repo,
            appendixId: approvedAppendix,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Gia hạn được duyệt – Chờ ký phụ lục'), findsOneWidget);
      expect(find.textContaining(approvedAppendix), findsOneWidget);
      expect(find.textContaining('Hạn ký: 23/10/2026 11:03'), findsOneWidget);
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Xem và ký phụ lục'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      repo.json = detail(
        'TU_CHOI',
        id: rejectedContract,
        pid: rejectedAppendix,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ContractRenewalPage(
            contract:
                ContractDetailData.fromJson(
                  repo.json,
                  rejectedContract,
                ).contract,
            repository: repo,
            appendixId: rejectedAppendix,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Gia hạn bị từ chối'), findsOneWidget);
      expect(find.textContaining(rejection), findsOneWidget);
      expect(find.text('Xem và ký phụ lục'), findsNothing);
      expect(repo.writes, 0);
      expect(repo.pdfReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('expired CHO_KY never enables signing or requests PDF/OTP', (
    tester,
  ) async {
    final repo = DisplayRepository();
    repo.json['thoiGianServer'] = '2026-10-23T05:00:00Z';
    await tester.pumpWidget(
      MaterialApp(
        home: ContractRenewalPage(
          contract:
              ContractDetailData.fromJson(repo.json, approvedContract).contract,
          repository: repo,
          appendixId: approvedAppendix,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      tester
          .widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, 'Xem và ký phụ lục'),
          )
          .onPressed,
      isNull,
    );
    expect(repo.pdfReads, 0);
    expect(repo.writes, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'list refreshes on return/tab/resume without push',
    (tester) async {
      final repo = ListRepository()..rows = [summary('TEST')];
      final bloc = ContractListBloc(repository: repo)..add(LoadContracts());
      final visible = ValueNotifier(true);
      final router = GoRouter(
        observers: [appRouteObserver],
        routes: [
          GoRoute(
            path: '/',
            builder:
                (_, __) => BlocProvider.value(
                  value: bloc,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: visible,
                    builder:
                        (_, active, __) => TickerMode(
                          enabled: active,
                          child: const ContractListView(),
                        ),
                  ),
                ),
          ),
          GoRoute(
            path: '/other',
            builder: (_, __) => const Scaffold(body: Text('Other')),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final initial = repo.reads;

      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.reads, greaterThan(initial));

      router.push('/other');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final beforePop = repo.reads;

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(repo.reads, greaterThan(beforePop));

      final beforeResume = repo.reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.reads, greaterThan(beforeResume));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      await tester.runAsync(bloc.close);

      router.dispose();
      visible.dispose();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  for (final status in ['CHO_KY', 'TU_CHOI']) {
    testWidgets('$status inbox CTA opens correct contract and exact appendix', (
      tester,
    ) async {
      final repo = DisplayRepository()..json = detail(status);
      final notice = NotificationItemModel.fromJson({
        'maThongBao': 'NOTICE',
        'loai': 'GIA_HAN',
        'eventCode': 'EXTENSION_$status',
        'targetType': 'HOP_DONG',
        'targetId': approvedContract,
        'daDoc': true,
        'thoiGianGui': '2026-10-23T02:03:35Z',
      });
      final router = GoRouter(
        observers: [appRouteObserver],
        routes: [
          GoRoute(
            path: '/',
            builder:
                (_, __) => NotificationDetailPage(
                  notificationId: 'NOTICE',
                  initialItem: notice,
                  contractRepository: repo,
                ),
          ),
          GoRoute(
            path: '/contract/:id',
            builder:
                (_, state) => Scaffold(
                  body: Text(
                    '${state.pathParameters['id']} ${state.uri.queryParameters['action']} ${state.uri.queryParameters['appendixId']}',
                  ),
                ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.textContaining(status == 'TU_CHOI' ? rejection : 'Hạn ký:'),
        findsWidgets,
      );
      final text =
          status == 'CHO_KY' ? 'Xem phụ lục gia hạn' : 'Xem kết quả gia hạn';
      await tester.tap(find.text(text));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('$approvedContract renewal $approvedAppendix'),
        findsOneWidget,
      );
      expect(repo.writes, 0);
      expect(repo.pdfReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      router.dispose();
    });
  }
}
