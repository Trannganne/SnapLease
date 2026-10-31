import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/formatters/rental_time_formatter.dart';
import 'package:rentcam/core/widgets/app_availability_calendar.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/features/cart/data/repositories/dio_cart_repository.dart';
import 'package:rentcam/features/cart/domain/models/cart_item_model.dart';
import 'package:rentcam/features/cart/presentation/widgets/cart_item_card.dart';

Future<void> selectTime(
  WidgetTester tester,
  String key,
  String hour,
  String minute,
) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(find.byType(TimePickerDialog), findsOneWidget);
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('Xác nhận'));
  await tester.pumpAndSettle();
}

Future<void> openCalendar(
  WidgetTester tester, {
  DateTime? pickup,
  DateTime? dropoff,
  bool fixedPickup = false,
  required ValueChanged<Map<String, DateTime>?> onResult,
}) async {
  tester.view.physicalSize = const Size(390, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed: () async {
                  onResult(
                    await AppAvailabilityCalendar.show(
                      context,
                      currentPickup: pickup,
                      currentReturn: dropoff,
                      branchId: 'CNTEST',
                      deviceId: 'DMTEST',
                      quantity: 1,
                      fixedPickup: fixedPickup,
                    ),
                  );
                },
                child: const Text('Mở lịch'),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở lịch'));
  await tester.pumpAndSettle();
}

Future<void> applyCalendar(WidgetTester tester) async {
  final apply = find.widgetWithText(PrimaryButton, 'Áp dụng');
  await tester.ensureVisible(apply);
  await tester.tap(apply);
  await tester.pumpAndSettle();
}

TableCalendar calendar(WidgetTester tester) => tester.widget<TableCalendar>(
  find.byWidgetPredicate((widget) => widget is TableCalendar),
);

void main() {
  test(
    'rental interval keeps wall-clock hours and follows backend period limits',
    () {
      final pickup = RentalTimeFormatter.vietnamNow().add(
        const Duration(days: 2),
      );
      expect(RentalTimeFormatter.periodError(pickup, pickup), isNotNull);
      expect(
        RentalTimeFormatter.periodError(
          pickup,
          pickup.add(const Duration(days: 90)),
        ),
        isNull,
      );
      expect(
        RentalTimeFormatter.periodError(
          pickup,
          pickup.add(const Duration(days: 90, minutes: 1)),
        ),
        contains('90'),
      );
      expect(
        RentalTimeFormatter.periodError(
          pickup.subtract(const Duration(days: 3)),
          pickup,
        ),
        contains('tương lai'),
      );
      expect(
        RentalTimeFormatter.wallClock(DateTime(2026, 11, 23, 8, 15)),
        '2026-11-23T08:15:00',
      );
    },
  );
  final now = DateTime.now();
  final start = DateTime(now.year, now.month + 1, 5);
  final end = DateTime(now.year, now.month + 1, 7);
  late InterceptorsWrapper availability;
  late List<RequestOptions> requests;

  setUpAll(() => initializeDateFormatting('vi_VN'));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    availability = InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        expect(options.method, 'GET');
        expect(options.path, '/api/lich-trong/thang');
        final year = options.queryParameters['nam'] as int;
        final month = options.queryParameters['thang'] as int;
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'ngayList': [
                for (
                  var day = 1;
                  day <= DateTime(year, month + 1, 0).day;
                  day++
                )
                  {
                    'ngay': DateTime(year, month, day).toIso8601String(),
                    'trangThai': 'XANH',
                  },
              ],
            },
          ),
        );
      },
    );
    ApiClient.instance.interceptors.add(availability);
  });
  tearDown(() => ApiClient.instance.interceptors.remove(availability));

  testWidgets(
    'user selects 08:00 for both dates and cart payload keeps local hours',
    (tester) async {
      Map<String, DateTime>? result;
      await openCalendar(
        tester,
        pickup: start,
        dropoff: end,
        onResult: (value) => result = value,
      );
      // An existing midnight value stays visible until the user edits it.
      expect(find.text('00:00'), findsNWidgets(2));
      await selectTime(tester, 'rental-pickup-time', '08', '00');
      await selectTime(tester, 'rental-return-time', '08', '00');
      await applyCalendar(tester);
      expect(
        result!['pickup'],
        DateTime(start.year, start.month, start.day, 8),
      );
      expect(result!['return'], DateTime(end.year, end.month, end.day, 8));
      expect(
        DioCartRepository.localTime(result!['pickup']!),
        '${start.toIso8601String().substring(0, 10)}T08:00:00',
      );
      expect(
        DioCartRepository.localTime(result!['return']!),
        '${end.toIso8601String().substring(0, 10)}T08:00:00',
      );
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar day and range changes retain independently selected hours',
    (tester) async {
      Map<String, DateTime>? result;
      await openCalendar(
        tester,
        pickup: DateTime(start.year, start.month, start.day, 16, 10),
        dropoff: DateTime(end.year, end.month, end.day, 8, 25),
        onResult: (value) => result = value,
      );
      final nextStart = start.add(const Duration(days: 5));
      final nextEnd = end.add(const Duration(days: 5));
      calendar(tester).onDaySelected!(nextStart, nextStart);
      await tester.pump();
      calendar(tester).onDaySelected!(nextEnd, nextEnd);
      await tester.pump();
      expect(find.text('16:10'), findsOneWidget);
      expect(find.text('08:25'), findsOneWidget);
      // TableCalendar also publishes date-only UTC values through its range callback.
      calendar(tester).onRangeSelected!(
        DateTime.utc(nextStart.year, nextStart.month, nextStart.day),
        DateTime.utc(nextEnd.year, nextEnd.month, nextEnd.day),
        nextStart,
      );
      await tester.pump();
      await applyCalendar(tester);
      expect(
        result!['pickup'],
        DateTime(nextStart.year, nextStart.month, nextStart.day, 16, 10),
      );
      expect(
        result!['return'],
        DateTime(nextEnd.year, nextEnd.month, nextEnd.day, 8, 25),
      );
      expect(result!['pickup']!.isUtc, isFalse);
      expect(result!['return']!.isUtc, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-day return must be strictly later; missing time blocks apply',
    (tester) async {
      Map<String, DateTime>? result;
      await openCalendar(
        tester,
        pickup: DateTime(start.year, start.month, start.day, 10),
        onResult: (value) => result = value,
      );
      calendar(tester).onRangeSelected!(start, start, start);
      await tester.pump();
      expect(find.text('Chọn giờ'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      await selectTime(tester, 'rental-return-time', '09', '00');
      expect(find.text('Giờ trả phải sau giờ nhận.'), findsOneWidget);
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      await selectTime(tester, 'rental-return-time', '10', '00');
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull,
      );
      await selectTime(tester, 'rental-return-time', '10', '01');
      await applyCalendar(tester);
      expect(
        result!['return'],
        DateTime(start.year, start.month, start.day, 10, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renewal keeps fixed pickup and date-only return without time controls or HTTP',
    (tester) async {
      Map<String, DateTime>? result;
      final fixed = DateTime(start.year, start.month, start.day, 9, 37);
      await openCalendar(
        tester,
        pickup: fixed,
        fixedPickup: true,
        onResult: (value) => result = value,
      );
      expect(find.byKey(const ValueKey('rental-pickup-time')), findsNothing);
      expect(find.byKey(const ValueKey('rental-return-time')), findsNothing);
      expect(calendar(tester).enabledDayPredicate!(start), isFalse);
      calendar(tester).onDaySelected!(end, end);
      await tester.pump();
      await applyCalendar(tester);
      expect(result!['pickup'], fixed);
      expect(result!['return'], end);
      expect(requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cart shows both actual date/time values on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final pickup = DateTime(start.year, start.month, start.day, 8);
    final dropoff = DateTime(end.year, end.month, end.day, 9, 30);
    final item = CartItemModel(
      id: 'TEST-CART',
      branchId: 'CNTEST',
      branchName: 'Chi nhánh test',
      modelId: 'DMTEST',
      modelName: 'Canon EOS R6',
      imageUrl: '',
      dailyPrice: 100000,
      depositPrice: 200000,
      startDate: pickup,
      endDate: dropoff,
      rentalDays: 3,
      quantity: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CartItemCard(
            item: item,
            isEditMode: false,
            onSelectionChanged: (_) {},
            onQuantityChanged: (_) {},
            onDeletePressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    String date(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
    expect(
      find.text('Nhận: 08:00 ${date(pickup)}\nTrả: 09:30 ${date(dropoff)}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
