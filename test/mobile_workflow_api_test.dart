import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/features/cart/data/repositories/dio_cart_repository.dart';
import 'package:rentcam/features/notification/data/repositories/notification_repository.dart';
import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/notification/bloc/notification_detail_cubit.dart';
import 'package:rentcam/features/contract/data/contract_detail_data.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/data/repositories/appendix_signing_repository.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/features/contract/domain/models/extension_models.dart';
import 'contract_handover_test.dart' show fixture;

Dio http(FutureOr<Object?> Function(RequestOptions) handle) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) async {
        try {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: await handle(request),
            ),
          );
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return dio;
}

Map<String, dynamic> line(
  String id, {
  String branch = 'A',
  String version = 'v1',
  num price = 100.25,
}) => {
  'maChiTietGioHang': id,
  'phienBan': version,
  'maCuaHang': branch,
  'tenCuaHang': 'Chi nhánh $branch',
  'maDongMay': 'M$id',
  'tenDongMay': 'Camera $id',
  'soLuong': 1,
  'ngayBatDau': '2026-12-01T09:00:00',
  'ngayKetThuc': '2026-12-02T09:00:00',
  'khaDung': true,
  'soLuongConTrong': 4,
  'baoGia': {
    'donGiaSauGiam': price,
    'tongTienThue': price,
    'tongTienCoc': 1000.50,
    'tienCocMotDonVi': 1000.50,
    'soNgayTinhPhi': 1,
  },
};
Map<String, dynamic> hold() => {
  'maGiuCho': 'GC1',
  'trangThai': 'DANG_GIU',
  'hetHanLuc': '2026-12-01T02:20:00Z',
  'thoiGianServer': '2026-12-01T02:00:00Z',
  'daXacNhanThongTin': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('vi_VN'));
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'offline-account-A',
    });
  });
  test(
    'production cart shares authenticated ApiClient and keeps server decimal totals',
    () async {
      expect(identical(DioCartRepository().dio, ApiClient.instance), true);
      final repository = DioCartRepository(dio: http((_) => [line('1')]));
      final items = await repository.getCartItems();
      expect(items.single.itemTotalPrice, 100.25);
      expect(items.single.itemTotalDeposit, 1000.50);
      expect(items.single.version, 'v1');
    },
  );
  test(
    'partial checkout sends only selected identities and versions, never prices',
    () async {
      final requests = <RequestOptions>[];
      final repository = DioCartRepository(
        dio: http((r) {
          requests.add(r);
          return r.method == 'GET' ? [line('1'), line('2')] : hold();
        }),
      );
      final items = await repository.getCartItems();
      await repository.checkout([items.first]);
      final post = requests.singleWhere((r) => r.method == 'POST');
      expect(post.data, {
        'items': [
          {'id': '1', 'phienBan': 'v1'},
        ],
      });
      expect(post.headers['Idempotency-Key'], isNotEmpty);
      expect(
        (await repository.getCartItems()).length,
        2,
        reason: 'Hold creation must not remove cart lines',
      );
    },
  );
  test('timeout is reconciled by saved key before any repeat POST', () async {
    var posts = 0;
    var reconciles = 0;
    final repository = DioCartRepository(
      dio: http((r) {
        if (r.method == 'POST') {
          posts++;
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.receiveTimeout,
          );
        }
        if (r.path.contains('/checkout/')) {
          reconciles++;
          return hold();
        }
        return [line('1')];
      }),
    );
    final items = await repository.getCartItems();
    await expectLater(repository.checkout(items), throwsA(isA<CartFailure>()));
    expect((await repository.checkout(items))['maGiuCho'], 'GC1');
    expect(posts, 1);
    expect(reconciles, 1);
  });
  test('mixed branches fail before creating a reservation', () async {
    var calls = 0;
    final repository = DioCartRepository(
      dio: http((r) {
        calls++;
        return hold();
      }),
    );
    await expectLater(
      repository.checkout([
        DioCartRepository.fromJson(line('1')),
        DioCartRepository.fromJson(line('2', branch: 'B')),
      ]),
      throwsA(isA<CartFailure>()),
    );
    expect(calls, 0);
  });
  test('late cart response from old session is discarded', () async {
    final pending = Completer<Object?>();
    final repository = DioCartRepository(dio: http((_) => pending.future));
    final request = repository.getCartItems();
    await Future<void>.delayed(Duration.zero);
    await TokenStorage.saveToken('offline-account-B');
    repository.invalidateSession();
    pending.complete([line('A')]);
    await expectLater(request, throwsA(isA<CartFailure>()));
  });
  test(
    'server group filters precede pagination request and total is authoritative',
    () async {
      final requests = <RequestOptions>[];
      final repository = DioNotificationRepository(
        dio: http((r) {
          requests.add(r);
          return {'trang': 3, 'kichThuocTrang': 2, 'tongSo': 9, 'duLieu': []};
        }),
      );
      final result = await repository.getNotifications(
        category: NotificationCategory.payment,
        page: 3,
        pageSize: 2,
      );
      expect(requests.single.queryParameters, {
        'trang': 3,
        'kichThuocTrang': 2,
        'nhom': 'THANH_TOAN',
      });
      expect(result.totalCount, 9);
      expect(result.items, isEmpty);
    },
  );
  test(
    'push cold start loads notification by actual ID and maps backend target exactly',
    () async {
      var gets = 0;
      final repository = DioNotificationRepository(
        dio: http((r) {
          if (r.method == 'PUT') return null;
          gets++;
          expect(r.path, '/api/thong-bao/TB1');
          return {
            'maThongBao': 'TB1',
            'loai': 'GIA_HAN',
            'tieuDe': 'Gia hạn',
            'noiDung': 'Nội dung',
            'thoiGianGui': '2026-11-01T02:00:00Z',
            'daDoc': true,
            'eventCode': 'EXTENSION_CHO_KY',
            'targetType': 'HOP_DONG',
            'targetId': 'HD1',
          };
        }),
      );
      final cubit = NotificationDetailCubit(
        notificationId: 'TB1',
        notificationRepository: repository,
      );
      if (cubit.state.item == null && cubit.state.error == null) {
        await cubit.stream
            .firstWhere((s) => s.item != null || s.error != null)
            .timeout(const Duration(seconds: 5));
      }
      expect(cubit.state.error, isNull);
      expect(gets, 1);
      expect(cubit.state.item!.targetId, 'HD1');
      expect(cubit.state.item!.targetType, NotificationTargetType.contract);
      await cubit.close();
    },
  );
  test(
    'approved awaiting-sign never changes effective return; only signed state does',
    () {
      final json = {
        ...fixture(status: 'DANG_THUE'),
        'phuLuc': [
          {
            'maPhuLuc': 'PL1',
            'trangThai': 'CHO_KY',
            'thoiHanTraMoi': '2027-01-01T10:00:00',
          },
        ],
      };
      final pending = ContractDetailData.fromJson(json, 'HDTEST').contract;
      expect(pending.effectiveReturnDate, pending.returnDate);
      json['phuLuc'] = [
        {
          'maPhuLuc': 'PL1',
          'trangThai': 'DA_HIEU_LUC',
          'thoiHanTraMoi': '2027-01-01T10:00:00',
        },
      ];
      expect(
        ContractDetailData.fromJson(
          json,
          'HDTEST',
        ).contract.effectiveReturnDate,
        DateTime(2027, 1, 1, 10),
      );
    },
  );
  test(
    'contract and formatter preserve Backend decimal amounts through PDF model',
    () {
      final json = {
        ...fixture(),
        'tongTien': 100.25,
        'tongTienCoc': 1000.50,
        'datTheoDongMay': [
          {
            'maDongMay': 'M1',
            'tenDongMay': 'Camera',
            'soLuong': 1,
            'donGiaTieuChuan': 100.25,
            'thanhTien': 100.25,
          },
        ],
      };
      final model = ContractDetailData.fromJson(json, 'HDTEST').contract;
      expect(model.rentalTotal, 100.25);
      expect(model.deposit, 1000.50);
      expect(model.totalAmount, 1100.75);
      expect(model.pricePerDay, 100.25);
      expect(model.bookedDevices.single.rentalTotal, 100.25);
      expect(
        const AppMoneyFormatter().format(model.rentalTotal),
        contains('100,25'),
      );
      expect(const AppMoneyFormatter().format(100), isNot(contains(',00')));
    },
  );
  test(
    'appendix consent reads the frozen Backend clauses and never substitutes new base terms',
    () {
      const clause = 'Bảo lưu ngoại lệ lý do chính đáng trong hợp đồng gốc.';
      expect(
        appendixTermsText({
          'noiDungJson': jsonEncode({
            'dieuKhoan': [clause],
          }),
        }),
        clause,
      );
      expect(() => appendixTermsText({}), throwsFormatException);
    },
  );
  test(
    'cart period/branch edit sends version and no client money, preserving selection',
    () async {
      RequestOptions? update;
      final repository = DioCartRepository(
        dio: http((r) {
          if (r.method == 'GET') return [line('1')];
          update = r;
          return {
            ...line('1', branch: 'B', version: 'v2'),
            'ngayKetThuc': '2026-12-03T09:00:00',
          };
        }),
      );
      await repository.getCartItems();
      final item = await repository.toggleItemSelection(
        cartItemId: '1',
        isSelected: true,
      );
      final updated = await repository.updateItem(
        item,
        branchId: 'B',
        end: DateTime(2026, 12, 3, 9),
      );
      expect(update!.data, {
        'maDongMay': 'M1',
        'maCuaHang': 'B',
        'soLuong': 1,
        'ngayBatDau': '2026-12-01T09:00:00',
        'ngayKetThuc': '2026-12-03T09:00:00',
        'phienBan': 'v1',
      });
      expect(updated.version, 'v2');
      expect(updated.isSelected, true);
    },
  );
  test(
    'UTC notification timestamp preserves its instant and is displayed in local time',
    () {
      final item = NotificationItemModel.fromJson({
        'maThongBao': 'TBUTC',
        'loai': 'HOP_DONG',
        'thoiGianGui': '2026-12-01T02:00:00Z',
      });
      expect(item.sentAt.isUtc, false);
      expect(item.sentAt.toUtc(), DateTime.utc(2026, 12, 1, 2));
    },
  );
  for (final status in [
    'TU_CHOI',
    'HET_HAN_XU_LY',
    'HET_HAN_KY',
    'DONG_QUY_TRINH_CU',
  ]) {
    test(
      '$status never changes the effective return or creates a pending extension',
      () {
        final model =
            ContractDetailData.fromJson({
              ...fixture(status: 'DANG_THUE'),
              'phuLuc': [
                {
                  'maPhuLuc': 'PL1',
                  'trangThai': status,
                  'thoiHanTraMoi': '2027-01-01T10:00:00',
                },
              ],
            }, 'HDTEST').contract;
        expect(model.effectiveReturnDate, model.returnDate);
        expect(model.proposedReturnDate, isNull);
      },
    );
  }
  test(
    'appendix signing timeout reconciles once and requires effective state',
    () async {
      final contract =
          ContractDetailData.fromJson(
            fixture(status: 'DANG_THUE'),
            'HDTEST',
          ).contract;
      var signed = false;
      var writes = 0;
      final repository = AppendixSigningRepository(
        'PL1',
        dio: http((r) {
          if (r.method == 'POST') {
            return {
              'maXacNhan': 'XP1',
              'maBamNoiDung': 'CONTENT',
              'hetHanLuc': '2026-12-01T04:00:00Z',
            };
          }
          if (r.method == 'PUT') {
            writes++;
            expect((r.data as Map)['maBamNoiDung'], 'CONTENT');
            signed = true;
            throw DioException(
              requestOptions: r,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return {
            'maPhuLuc': 'PL1',
            'trangThai': signed ? 'DA_HIEU_LUC' : 'CHO_KY',
            'maBamTepPdf': 'FROZEN',
            'thoiHanTraMoi': '2027-01-01T10:00:00',
          };
        }),
      );
      await repository.uploadPdfAndRequestOtp(contract, Uint8List(0), true);
      final updated = await repository.verifyOtp(
        contract,
        'XP1',
        '123456',
        true,
      );
      expect(writes, 1);
      expect(updated.effectiveReturnDate, DateTime(2027, 1, 1, 10));
    },
  );
  testWidgets(
    'cancellation payable and actual refund remain separate on the contract screen',
    (tester) async {
      final json = {
        ...fixture(status: 'DA_HUY'),
        'yeuCauHuy': [
          {
            'id': 'YH1',
            'trangThai': 'DA_DUYET',
            'tienKhauTru': 30,
            'tienCocPhaiHoan': 70,
            'tienThuePhaiHoan': 50,
            'tienThuThuaPhaiHoan': 100,
          },
        ],
        'hoanTienHuy': [
          {
            'maThanhToan': 'TT1',
            'loaiThanhToan': 'HOAN_THU_THUA',
            'soTien': 100,
            'trangThai': 'CHO_THANH_TOAN',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ContractPage(
            contractId: 'HDTEST',
            repository: ContractRepository(dio: http((_) => json)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yêu cầu hủy và khoản phải hoàn'), findsOneWidget);
      expect(
        find.textContaining('Thu thừa phải hoàn đủ: 100đ'),
        findsOneWidget,
      );
      expect(find.textContaining('chưa xác nhận hoàn'), findsOneWidget);
      expect(find.textContaining('Đã xác nhận hoàn thực tế'), findsNothing);
    },
  );
}
