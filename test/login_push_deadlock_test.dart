import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import 'package:rentcam/features/auth/data/auth_repository.dart';
import 'package:rentcam/features/auth/login/bloc/login_bloc.dart';
import 'package:rentcam/features/auth/login/bloc/login_event.dart';
import 'package:rentcam/features/auth/login/bloc/login_state.dart';
import 'package:rentcam/features/auth/login/presentation/login_page.dart';
import 'package:rentcam/features/notification/data/push_service.dart';

// Every HTTP request is intercepted here. No trial API or provider is contacted.
class _Http implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  _Http(this.reply);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => reply(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

const _loginReply = {
  'accessToken': 'unit-new-session',
  'maTaiKhoan': 'UNIT_ACCOUNT',
};

class _Permission extends Fake implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.authorized;
}

class _Messaging extends Fake implements FirebaseMessaging {
  final registered = StreamController<String>.broadcast(sync: true);
  final unregisterGate = Completer<void>();
  int registrations = 0;
  int unregistrations = 0;
  bool enabled = true;

  @override
  Stream<String> get onRegistered => registered.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<void> register({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    registrations++;
    registered.add('unit-fid');
  }

  @override
  Future<void> unregister() {
    unregistrations++;
    return unregisterGate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) {
      return Future<NotificationSettings>.value(
        enabled ? _Permission() : _DeniedPermission(),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _DeniedPermission extends _Permission {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.denied;
}

class _Push extends PushService {
  final _Messaging fake;
  _Push(this.fake);

  @override
  FirebaseMessaging get messaging => fake;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter originalAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.beforeSessionChange = null;
    TokenStorage.sessionCleanups.clear();
    originalAdapter = ApiClient.instance.httpClientAdapter;
  });

  tearDown(() {
    TokenStorage.beforeSessionChange = null;
    ApiClient.instance.httpClientAdapter = originalAdapter;
  });

  test('expired push binding cannot deadlock session cleanup or login', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.access_token': 'unit-expired-session',
      'flutter.session_account_id': 'UNIT_OLD_ACCOUNT',
    });
    final messaging = _Messaging();
    final push = _Push(messaging);
    final acceptedBinding = Completer<void>();
    var loginRequests = 0;
    ApiClient.instance.httpClientAdapter = _Http((request) {
      if (request.path == '/api/thong-bao/fcm-token') {
        if (request.headers['Authorization'] == 'Bearer unit-expired-session') {
          return _json({}, 401);
        }
        if (!acceptedBinding.isCompleted) acceptedBinding.complete();
        return _json({'id': 'UNIT_DEVICE'});
      }
      if (request.path == '/api/auth/login') {
        loginRequests++;
        return _json(_loginReply);
      }
      if (request.method == 'DELETE') return _json({}, 204);
      throw StateError('Unexpected mocked request');
    });
    LoginBloc? bloc;
    try {
      final cleared = TokenStorage.changes.first;
      await push.start();
      // Regression: onError -> deleteToken -> unlink -> same _binding Future.
      await cleared.timeout(const Duration(seconds: 1));
      expect(await TokenStorage.getToken(), isNull);
      expect(TokenStorage.isChanging, isFalse);
      expect(messaging.unregisterGate.isCompleted, isFalse);

      bloc = LoginBloc(authRepository: AuthRepository());
      final completed = bloc.stream.firstWhere(
        (state) => state.status == LoginStatus.success,
      );
      bloc.add(
        const LoginSubmitted(
          emailOrPhone: 'unit.customer',
          password: 'unit-only-not-a-real-password',
        ),
      );
      await completed.timeout(const Duration(seconds: 1));
      expect(await TokenStorage.getToken(), 'unit-new-session');
      expect(await TokenStorage.getAccountId(), 'UNIT_ACCOUNT');
      expect(loginRequests, 1);
      expect(messaging.registrations, 1);

      // Optional transport cleanup can be slow; new registration stays ordered.
      messaging.unregisterGate.complete();
      await acceptedBinding.future.timeout(const Duration(seconds: 1));
      expect(messaging.registrations, 2);
    } finally {
      messaging.enabled = false;
      if (!messaging.unregisterGate.isCompleted) {
        messaging.unregisterGate.complete();
      }
      if (bloc != null) await bloc.close();
      await messaging.registered.close();
    }
  });

  test(
    'late cleanup 401 uses its original session and preserves the new one',
    () async {
      SharedPreferences.setMockInitialValues({
        'flutter.access_token': 'unit-current-session',
        'flutter.session_account_id': 'UNIT_CURRENT_ACCOUNT',
      });
      String? authorization;
      ApiClient.instance.httpClientAdapter = _Http((request) {
        authorization = request.headers['Authorization'] as String?;
        return _json({}, 401);
      });
      await expectLater(
        ApiClient.instance.delete<void>(
          '/api/thong-bao/fcm-token/UNIT_OLD_DEVICE',
          options: Options(
            headers: {'Authorization': 'Bearer unit-old-session'},
            extra: {'sessionCleanup': true},
          ),
        ),
        throwsA(isA<DioException>()),
      );
      expect(authorization, 'Bearer unit-old-session');
      expect(await TokenStorage.getToken(), 'unit-current-session');
      expect(await TokenStorage.getAccountId(), 'UNIT_CURRENT_ACCOUNT');
    },
  );

  Future<void> showLogin(WidgetTester tester, ResponseBody reply) async {
    ApiClient.instance.httpClientAdapter = _Http((_) => reply);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder:
              (_, _) => BlocProvider(
                create: (_) => LoginBloc(authRepository: AuthRepository()),
                child: const LoginView(),
              ),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('UNIT_HOME')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'unit.customer');
    await tester.enterText(find.byType(TextField).at(1), 'unit-only-password');
    final button = find.byType(PrimaryButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('successful login ends loading and navigates home', (
    tester,
  ) async {
    await showLogin(tester, _json(_loginReply));
    expect(find.text('UNIT_HOME'), findsOneWidget);
    expect(find.text('Đang đăng nhập'), findsNothing);
  });

  testWidgets('rejected login ends loading and displays the server error', (
    tester,
  ) async {
    await showLogin(tester, _json({}, 401));
    expect(
      find.text('Sai mật khẩu hoặc tài khoản không tồn tại.'),
      findsOneWidget,
    );
    expect(find.text('UNIT_HOME'), findsNothing);
    expect(
      tester
          .widget<SnapLoadingOverlay>(find.byType(SnapLoadingOverlay))
          .loading,
      isFalse,
    );
  });
}
