import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/features/chat/data/chat_history_store.dart';
import 'package:rentcam/features/chat/data/dio_chat_repository.dart';
import 'package:rentcam/features/chat/domain/chat_models.dart';
import 'package:rentcam/features/chat/domain/chat_repository.dart';
import 'package:rentcam/features/chat/presentation/chat_cubit.dart';
import 'package:rentcam/features/chat/presentation/chat_page.dart';
import 'package:rentcam/features/home/presentation/widgets/product_card.dart';

class FakeChat implements ChatRepository {
  int calls = 0;
  Completer<ChatMessage>? pending;
  bool enabled = true;
  String? failure;
  @override
  Future<String> account(CancelToken cancel) async =>
      (await TokenStorage.getAccountId())!;
  @override
  Future<ChatStatus> status(CancelToken cancel) async =>
      ChatStatus(enabled, enabled ? null : 'Chưa bật AI');
  @override
  Future<ChatMessage> send(
    String text,
    List<ChatMessage> history,
    CancelToken cancel,
  ) async {
    calls++;
    if (failure != null) throw ChatFailure(failure!);
    return pending == null
        ? ChatMessage(
          role: 'assistant',
          text: 'Nội dung đã duyệt',
          at: DateTime.now().toUtc(),
        )
        : pending!.future;
  }

  @override
  Future<int> availability(
    String productId,
    String branchId,
    DateTime start,
    DateTime end,
    CancelToken cancel,
  ) async => 1;
}

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) reply;
  Adapter(this.reply);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => reply(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody body(Object data, int code) => ResponseBody.fromString(
  jsonEncode(data),
  code,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.sessionCleanups.clear();
    TokenStorage.beforeSessionChange = null;
    await TokenStorage.saveToken('synthetic-A', accountId: 'ACCOUNT-A');
  });
  test('history survives closing/reopening and expires at 30 days', () async {
    final now = DateTime.utc(2026, 10, 24, 1);
    final store = ChatHistoryStore(now: () => now)..attach();
    await store.save('ACCOUNT-A', [
      ChatMessage(
        role: 'user',
        text: 'old',
        at: now.subtract(const Duration(days: 30)),
      ),
      ChatMessage(
        role: 'user',
        text: 'kept',
        at: now.subtract(const Duration(days: 29)),
      ),
    ], TokenStorage.generation);
    expect((await store.load('ACCOUNT-A')).map((m) => m.text), ['kept']);
    final reopened = ChatHistoryStore(now: () => now);
    expect((await reopened.load('ACCOUNT-A')).single.text, 'kept');
    expect(await store.load('ACCOUNT-B'), isEmpty);
  });
  test(
    'logout clears prior account even when chat screen is closed; push cleanup preserved',
    () async {
      final store = ChatHistoryStore()..attach();
      var unlinks = 0;
      TokenStorage.beforeSessionChange = () async {
        unlinks++;
      };
      await store.save('ACCOUNT-A', [
        ChatMessage(
          role: 'user',
          text: 'A private local thread',
          at: DateTime.now().toUtc(),
        ),
      ], TokenStorage.generation);
      await TokenStorage.deleteToken();
      expect(await store.load('ACCOUNT-A'), isEmpty);
      expect(await TokenStorage.getAccountId(), isNull);
      expect(unlinks, 1);
      await TokenStorage.saveToken('synthetic-B', accountId: 'ACCOUNT-B');
      expect(await store.load('ACCOUNT-B'), isEmpty);
    },
  );
  test(
    'double send blocked, logout cancels and discards a late old-session answer',
    () async {
      final repo = FakeChat()..pending = Completer<ChatMessage>();
      final store = ChatHistoryStore();
      final cubit = ChatCubit(repository: repo, history: store);
      await cubit.load();
      final first = cubit.send('tư vấn chân dung');
      await Future<void>.delayed(Duration.zero);
      await cubit.send('gửi trùng');
      expect(repo.calls, 1);
      await TokenStorage.deleteToken();
      await TokenStorage.saveToken('synthetic-B', accountId: 'ACCOUNT-B');
      repo.pending!.complete(
        ChatMessage(
          role: 'assistant',
          text: 'LATE ACCOUNT A',
          at: DateTime.now().toUtc(),
        ),
      );
      await first;
      expect(cubit.state.messages, isEmpty);
      expect(await store.load('ACCOUNT-A'), isEmpty);
      expect(await store.load('ACCOUNT-B'), isEmpty);
      await cubit.close();
    },
  );
  test(
    'confirmed clear cancels pending response and remains cleared',
    () async {
      final repo = FakeChat()..pending = Completer<ChatMessage>();
      final store = ChatHistoryStore();
      final cubit = ChatCubit(repository: repo, history: store);
      await cubit.load();
      final send = cubit.send('thuê máy');
      await Future<void>.delayed(Duration.zero);
      await cubit.clearHistory();
      repo.pending!.complete(
        ChatMessage(
          role: 'assistant',
          text: 'LATE',
          at: DateTime.now().toUtc(),
        ),
      );
      await send;
      expect(cubit.state.messages, isEmpty);
      expect(await store.load('ACCOUNT-A'), isEmpty);
      await cubit.close();
    },
  );
  test(
    'quota/network error makes one call and retains user message for review',
    () async {
      final repo = FakeChat()..failure = 'Hết hạn mức miễn phí';
      final cubit = ChatCubit(repository: repo, history: ChatHistoryStore());
      await cubit.load();
      await cubit.send('thuê máy');
      expect(repo.calls, 1);
      expect(cubit.state.sending, isFalse);
      expect(cubit.state.error, contains('hạn mức'));
      expect(cubit.state.messages.single.role, 'user');
      await cubit.close();
    },
  );
  test(
    'closing cubit ignores late response and reopening reads stored conversation',
    () async {
      final repo = FakeChat()..pending = Completer<ChatMessage>();
      final store = ChatHistoryStore();
      final cubit = ChatCubit(repository: repo, history: store);
      await cubit.load();
      final send = cubit.send('hello');
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repo.pending!.complete(
        ChatMessage(
          role: 'assistant',
          text: 'LATE',
          at: DateTime.now().toUtc(),
        ),
      );
      await send;
      final next = ChatCubit(repository: FakeChat(), history: store);
      await next.load();
      expect(next.state.messages.single.text, 'hello');
      await next.close();
    },
  );
  test(
    'Dio uses existing contract, sends only last three user turns, rejects empty reply',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'));
      var calls = 0;
      dio.httpClientAdapter = Adapter((request) async {
        calls++;
        expect(request.path, '/api/tro-ly/tin-nhan');
        final data = request.data as Map;
        expect((data['history'] as List).length, 3);
        expect(
          (data['history'] as List).every((e) => e['role'] == 'user'),
          isTrue,
        );
        return body({
          'text': '',
          'products': [],
          'sources': [],
          'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
        }, 200);
      });
      final history = [
        for (var i = 0; i < 8; i++)
          ChatMessage(
            role: i.isEven ? 'user' : 'assistant',
            text: '$i',
            at: DateTime.now().toUtc(),
          ),
      ];
      await expectLater(
        DioChatRepository(dio: dio).send('hello', history, CancelToken()),
        throwsA(isA<ChatFailure>()),
      );
      expect(calls, 1);
    },
  );
  test('quota does not retry POST', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'));
    var calls = 0;
    dio.httpClientAdapter = Adapter((_) async {
      calls++;
      return body({'code': 'AI_QUOTA'}, 429);
    });
    await expectLater(
      DioChatRepository(dio: dio).send('hello', [], CancelToken()),
      throwsA(isA<ChatFailure>()),
    );
    expect(calls, 1);
  });
  test(
    'availability requires valid branch/period and validates returned model identity',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.invalid'));
      var calls = 0;
      dio.httpClientAdapter = Adapter((_) async {
        calls++;
        return body({
          'maDongMay': 'WRONG',
          'maCuaHang': 'SYNTHETIC',
          'soLuongConTrong': 1,
        }, 200);
      });
      final repo = DioChatRepository(dio: dio);
      final start = DateTime(2026, 11, 1, 8), end = DateTime(2026, 11, 2, 8);
      await expectLater(
        repo.availability('MODEL', '', start, end, CancelToken()),
        throwsA(isA<ChatFailure>()),
      );
      expect(calls, 0);
      await expectLater(
        repo.availability('MODEL', 'SYNTHETIC', end, start, CancelToken()),
        throwsA(isA<ChatFailure>()),
      );
      expect(calls, 0);
      await expectLater(
        repo.availability('MODEL', 'SYNTHETIC', start, end, CancelToken()),
        throwsA(isA<ChatFailure>()),
      );
      expect(calls, 1);
    },
  );
  test('malformed cached product IDs and money fail closed', () {
    final fractional = ChatProduct.fromJson({
      'maDongMay': 'REAL',
      'tenDongMay': 'Name',
      'giaThueNgay': 123456.78,
      'phanTramGiamGia': 0,
    });
    expect(fractional.product.pricePerDay, contains('123.456,78'));
    for (final price in [-1, double.nan, double.infinity]) {
      expect(
        () => ChatProduct.fromJson({
          'maDongMay': 'REAL',
          'tenDongMay': 'Name',
          'giaThueNgay': price,
          'phanTramGiamGia': 0,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ChatProduct.fromJson({
        'maDongMay': '../../payment',
        'tenDongMay': 'Name',
        'giaThueNgay': 1,
        'phanTramGiamGia': 0,
      }),
      throwsFormatException,
    );
  });
  test(
    'reload during a pending session cleanup cannot reattach the old account',
    () async {
      final repo = FakeChat();
      final cubit = ChatCubit(repository: repo, history: ChatHistoryStore());
      await cubit.load();
      final unlink = Completer<void>();
      TokenStorage.beforeSessionChange = () => unlink.future;
      final logout = TokenStorage.deleteToken();
      await Future<void>.delayed(Duration.zero);
      await cubit.load();
      expect(cubit.state.enabled, isFalse);
      expect(cubit.state.messages, isEmpty);
      unlink.complete();
      await logout;
      expect(cubit.state.enabled, isFalse);
      await cubit.close();
    },
  );
  testWidgets(
    'reused product card hides availability/add action and opens exact real model ID',
    (tester) async {
      final product = ChatProduct.fromJson({
        'maDongMay': 'SYNTHETIC-MODEL',
        'tenDongMay': 'Synthetic device',
        'giaThueNgay': 123456,
        'phanTramGiamGia': 0,
        'tenDanhMuc': 'Máy ảnh',
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder:
                (_, state) => Scaffold(
                  body: SizedBox(
                    width: 210,
                    height: 280,
                    child: ProductCard(
                      product: product.product,
                      showAvailability: false,
                      showAddAction: false,
                      showReviews: false,
                    ),
                  ),
                ),
          ),
          GoRoute(
            path: '/device/:id',
            builder:
                (_, state) => Scaffold(
                  body: Text('DEVICE ${state.pathParameters['id']}'),
                ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.text('Sẵn máy'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.star), findsNothing);
      await tester.tap(find.text('Chi tiết'));
      await tester.pumpAndSettle();
      expect(find.text('DEVICE SYNTHETIC-MODEL'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'chat keyboard/layout and delete confirmation at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakeChat();
        final store = ChatHistoryStore();
        await tester.pumpWidget(
          MaterialApp(home: ChatPage(repository: repo, history: store)),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.byType(TextField), 'Cách thuê máy?');
        await tester.tap(find.text('Gửi'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Nội dung đã duyệt'), findsOneWidget);
        await tester.tap(find.byTooltip('Xóa lịch sử'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Xóa lịch sử?'), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Nội dung đã duyệt'), findsOneWidget);
        tester.view.viewInsets = FakeViewPadding(bottom: 280);
        await tester.pump();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'dark theme and large text remain scrollable above keyboard on short screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: ChatPage(
            repository: FakeChat()..enabled = false,
            history: ChatHistoryStore(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Gửi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
