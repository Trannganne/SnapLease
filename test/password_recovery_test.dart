import 'dart:async';
import 'dart:io' show HttpDate;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/app/router/app_router.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/core/widgets/app_text_field.dart';
import 'package:rentcam/features/auth/data/auth_repository.dart';
import 'package:rentcam/features/auth/password_recovery/bloc/password_recovery_cubit.dart';
import 'package:rentcam/features/auth/password_recovery/presentation/password_recovery_page.dart';
import 'package:rentcam/features/auth/shared/auth_validation.dart';
import 'package:rentcam/features/auth/register/bloc/register_bloc.dart';
import 'package:rentcam/features/auth/register/bloc/register_event.dart';
import 'package:rentcam/features/auth/register/bloc/register_state.dart';

class RecoveryRepository extends AuthRepository {
  int requests = 0, resets = 0;
  int verificationRequests = 0, verifications = 0;
  String? email, token, password;
  Future<void> Function()? onRequest, onReset;
  Future<void> Function()? onVerify;
  @override
  Future<void> requestEmailVerification() async {
    verificationRequests++;
  }

  @override
  Future<void> verifyEmail(String value) async {
    verifications++;
    token = value;
    await onVerify?.call();
  }

  @override
  Future<void> requestPasswordRecovery(String email) async {
    requests++;
    this.email = email;
    await onRequest?.call();
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    resets++;
    token = resetToken;
    password = newPassword;
    await onReset?.call();
  }
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));
Dio http(
  int status, {
  Object? data,
  String? retryAfter,
  void Function(RequestOptions)? inspect,
  bool timeout = false,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (r, h) {
        inspect?.call(r);
        if (timeout) {
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.receiveTimeout,
            ),
          );
          return;
        }
        final response = Response(
          requestOptions: r,
          statusCode: status,
          data: data,
          headers: Headers.fromMap({
            if (retryAfter != null) 'retry-after': [retryAfter],
          }),
        );
        if (status >= 400) {
          h.reject(
            DioException(
              requestOptions: r,
              response: response,
              type: DioExceptionType.badResponse,
            ),
          );
        } else {
          h.resolve(response);
        }
      },
    ),
  );
  return dio;
}

GoRouter routes(
  RecoveryRepository repo, {
  bool reset = false,
  String? token = 'offline-token',
}) => GoRouter(
  initialLocation: reset ? AppRouter.resetPassword : AppRouter.forgotPassword,
  routes: [
    GoRoute(
      path: AppRouter.login,
      builder: (_, _) => const Scaffold(body: Text('LOGIN_FIXTURE')),
    ),
    GoRoute(
      path: AppRouter.forgotPassword,
      builder: (_, _) => ForgotPasswordPage(repository: repo),
    ),
    GoRoute(
      path: AppRouter.resetPassword,
      builder: (_, _) => ResetPasswordPage(repository: repo, resetToken: token),
    ),
  ],
);
Future<GoRouter> mount(
  WidgetTester tester,
  RecoveryRepository repo, {
  bool reset = false,
  String? token = 'offline-token',
  double scale = 1,
}) async {
  final router = routes(repo, reset: reset, token: token);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder field(int index) => find.descendant(
  of: find.byType(AppTextField).at(index),
  matching: find.byType(TextField),
);
Future<void> tapButton(WidgetTester tester, String text) async {
  final finder = find.widgetWithText(ElevatedButton, text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TokenStorage.beforeSessionChange = null;
  });
  tearDown(() {
    TokenStorage.beforeSessionChange = null;
  });
  test(
    'verification keeps the existing authenticated request and anonymous token DTO',
    () async {
      await TokenStorage.saveToken('offline-session');
      await AuthRepository(
        dio: http(
          202,
          inspect: (r) {
            expect(r.path, '/api/auth/email/xac-minh/gui');
            expect(r.data, isNull);
            expect(r.headers['Authorization'], 'Bearer offline-session');
          },
        ),
      ).requestEmailVerification();
      await AuthRepository(
        dio: http(
          204,
          inspect: (r) {
            expect(r.path, '/api/auth/email/xac-minh');
            expect(r.data, {'token': 'opaque+/%token=='});
          },
        ),
      ).verifyEmail('opaque+/%token==');
    },
  );
  test(
    'verification never sends on construction, requires user action, and handles unknown result',
    () async {
      final repo = RecoveryRepository();
      final cubit = PasswordRecoveryCubit(
        repository: repo,
        verificationToken: 'offline-token',
      );
      addTearDown(cubit.close);
      expect(repo.verifications, 0);
      await cubit.verifyEmail();
      expect(repo.verifications, 1);
      expect(cubit.state.status, PasswordRecoveryStatus.emailVerified);
      await cubit.verifyEmail();
      expect(repo.verifications, 1);
      final failing =
          RecoveryRepository()
            ..onVerify =
                () async =>
                    throw const PasswordRecoveryFailure(
                      RecoveryFailureKind.network,
                      uncertain: true,
                    );
      final unknown = PasswordRecoveryCubit(
        repository: failing,
        verificationToken: 'offline-token',
      );
      addTearDown(unknown.close);
      await unknown.verifyEmail();
      expect(unknown.state.uncertain, true);
      await unknown.verifyEmail();
      expect(failing.verifications, 1);
    },
  );
  testWidgets(
    'approved link routing strips token and requires a user click for verification',
    (tester) async {
      final dio = ApiClient.instance;
      final calls = <RequestOptions>[];
      final fixture = InterceptorsWrapper(
        onRequest: (r, h) {
          calls.add(r);
          h.resolve(Response(requestOptions: r, statusCode: 204));
        },
      );
      dio.interceptors.add(fixture);
      addTearDown(() => dio.interceptors.remove(fixture));
      final raw = 'offline+/%token==';
      final router = AppRouter.createRouter(
        initialLocation:
            'rentalcamera://auth-link/reset-password#token=${Uri.encodeComponent(raw)}',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRouter.resetPassword,
      );
      expect(calls, isEmpty);
      await tester.enterText(field(0), 'Abc123!x');
      router.go(
        'rentalcamera://auth-link/reset-password#token=${Uri.encodeComponent('second-offline-token')}',
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
      router.go(
        'rentalcamera://auth-link/verify-email#token=${Uri.encodeComponent(raw)}',
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.fragment, isEmpty);
      expect(calls, isEmpty);
      await tapButton(tester, 'Xác minh email');
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      expect(calls.single.path, '/api/auth/email/xac-minh');
      expect(calls.single.data, {'token': raw});
      expect(find.text('Email đã được xác minh'), findsOneWidget);
    },
  );

  test(
    'repository sends exact contract, trims email only, ignores accepted body',
    () async {
      final forgot = AuthRepository(
        dio: http(
          202,
          data: {'anything': 'ignored'},
          inspect: (r) {
            expect(r.path, '/api/auth/quen-mat-khau');
            expect(r.method, 'POST');
            expect(r.data, {'emailHoacSoDienThoai': 'user+camera@example.org'});
            expect(r.headers.containsKey('Authorization'), false);
          },
        ),
      );
      await forgot.requestPasswordRecovery(' user+camera@example.org ');
      final reset = AuthRepository(
        dio: http(
          204,
          inspect: (r) {
            expect(r.path, '/api/auth/dat-lai-mat-khau');
            expect(r.data, {
              'resetToken': 'opaque+/%token==',
              'matKhauMoi': ' Abc123! ',
            });
            expect((r.data as Map).containsKey('confirmPassword'), false);
          },
        ),
      );
      await reset.resetPassword(
        resetToken: 'opaque+/%token==',
        newPassword: ' Abc123! ',
      );
    },
  );
  test(
    'production client keeps recovery anonymous and cannot log out an unrelated session on 401',
    () async {
      await TokenStorage.saveToken('offline-session');
      final dio = ApiClient.instance;
      final fixture = InterceptorsWrapper(
        onRequest: (r, h) {
          expect(r.headers.containsKey('Authorization'), false);
          h.reject(
            DioException(
              requestOptions: r,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: r, statusCode: 401),
            ),
          );
        },
      );
      dio.interceptors.add(fixture);
      try {
        await expectLater(
          AuthRepository(
            dio: dio,
          ).requestPasswordRecovery('offline@example.org'),
          throwsA(isA<PasswordRecoveryFailure>()),
        );
        expect(await TokenStorage.getToken(), 'offline-session');
      } finally {
        dio.interceptors.remove(fixture);
      }
    },
  );
  test(
    'repository maps invalid token, 429 delta/date and timeout without leaking response',
    () async {
      await expectLater(
        AuthRepository(
          dio: http(
            400,
            data: {'code': 'INVALID_AUTH_LINK', 'internal': 'never expose'},
          ),
        ).resetPassword(resetToken: 'offline', newPassword: 'Abc123!x'),
        throwsA(
          isA<PasswordRecoveryFailure>().having(
            (e) => e.kind,
            'kind',
            RecoveryFailureKind.invalidLink,
          ),
        ),
      );
      for (final retry in [
        '30',
        HttpDate.format(DateTime.now().toUtc().add(const Duration(minutes: 1))),
      ]) {
        await expectLater(
          AuthRepository(
            dio: http(429, retryAfter: retry),
          ).requestPasswordRecovery('u@example.org'),
          throwsA(
            isA<PasswordRecoveryFailure>().having(
              (e) => e.retryAt,
              'retryAt',
              isNotNull,
            ),
          ),
        );
      }
      await expectLater(
        AuthRepository(
          dio: http(200, timeout: true),
        ).resetPassword(resetToken: 'offline', newPassword: 'Abc123!x'),
        throwsA(
          isA<PasswordRecoveryFailure>().having(
            (e) => e.uncertain,
            'uncertain',
            true,
          ),
        ),
      );
    },
  );
  test(
    'password validation matches all backend conditions and never trims',
    () {
      for (final bad in [
        '',
        'Ab1!',
        'abcdefgh!',
        'ABCDEFG1!',
        'Abcdefg!',
        'Abcdefg1',
        'A1!${'x' * 126}',
        '𝔄bcdef1!',
      ]) {
        expect(AuthValidation.passwordError(bad), isNotNull);
      }
      for (final valid in ['Abcdef1!', ' Abc123! ', 'ĐăngNhập1!', 'Abcdef١!']) {
        expect(AuthValidation.passwordError(valid), isNull);
      }
      expect(AuthValidation.emailError('camera+one@example.org'), isNull);
      expect(
        AuthValidation.emailError('invalid@domain with spaces'),
        isNotNull,
      );
    },
  );
  test(
    'registration reuses the same password rule and still sends its existing DTO',
    () async {
      int calls = 0;
      final repository = AuthRepository(
        dio: http(
          201,
          data: <String, dynamic>{},
          inspect: (r) {
            calls++;
            expect(r.path, '/api/auth/register');
            expect((r.data as Map).keys.toSet(), {
              'tenDangNhap',
              'email',
              'soDienThoai',
              'matKhau',
            });
          },
        ),
      );
      final bloc = RegisterBloc(authRepository: repository);
      addTearDown(bloc.close);
      RegisterSubmitted submit(String password) => RegisterSubmitted(
        username: 'fixture',
        email: 'offline@example.org',
        phone: '0000000000',
        password: password,
        confirmPassword: password,
        isTermsAccepted: true,
      );
      bloc.add(submit('NoSpecial1'));
      await tick();
      expect(bloc.state.passwordError, isNotNull);
      expect(calls, 0);
      bloc.add(submit('Abc123!x'));
      await tick();
      expect(bloc.state.status, RegisterStatus.success);
      expect(calls, 1);
    },
  );
  test(
    'forgot validates before send, single-flight, generic accepted and manual retry',
    () async {
      final repo = RecoveryRepository();
      final pending = Completer<void>();
      repo.onRequest = () => pending.future;
      final cubit = PasswordRecoveryCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.requestRecovery('invalid');
      expect(repo.requests, 0);
      expect(cubit.state.emailError, isNotNull);
      final first = cubit.requestRecovery(' user@example.org ');
      await cubit.requestRecovery('user@example.org');
      expect(repo.requests, 1);
      expect(cubit.state.loading, true);
      pending.complete();
      await first;
      expect(cubit.state.status, PasswordRecoveryStatus.accepted);
      expect(repo.email, 'user@example.org');
    },
  );
  test(
    '429 respects only a supplied Retry-After; no invented cooldown or automatic retry',
    () async {
      final repo =
          RecoveryRepository()
            ..onRequest =
                () async =>
                    throw PasswordRecoveryFailure(
                      RecoveryFailureKind.rateLimited,
                      retryAt: DateTime.now().toUtc().add(
                        const Duration(seconds: 30),
                      ),
                    );
      final cubit = PasswordRecoveryCubit(repository: repo);
      addTearDown(cubit.close);
      await cubit.requestRecovery('user@example.org');
      await cubit.requestRecovery('user@example.org');
      expect(repo.requests, 1);
      expect(cubit.state.message, contains('máy chủ'));
      final plainRepo =
          RecoveryRepository()
            ..onRequest =
                () async =>
                    throw const PasswordRecoveryFailure(
                      RecoveryFailureKind.rateLimited,
                    );
      final plain = PasswordRecoveryCubit(repository: plainRepo);
      addTearDown(plain.close);
      await plain.requestRecovery('user@example.org');
      await plain.requestRecovery('user@example.org');
      expect(plainRepo.requests, 2);
    },
  );
  test(
    'reset requires matching confirmation, single-flight, cleans existing session on 204',
    () async {
      await TokenStorage.saveToken('offline-session');
      int cleanup = 0;
      TokenStorage.beforeSessionChange = () async {
        cleanup++;
      };
      final repo = RecoveryRepository();
      final pending = Completer<void>();
      repo.onReset = () => pending.future;
      final cubit = PasswordRecoveryCubit(
        repository: repo,
        resetToken: 'opaque+/%token==',
      );
      addTearDown(cubit.close);
      await cubit.resetPassword('Abc123!x', 'different');
      expect(repo.resets, 0);
      expect(cubit.state.confirmationError, isNotNull);
      final first = cubit.resetPassword(' Abc123! ', ' Abc123! ');
      await cubit.resetPassword(' Abc123! ', ' Abc123! ');
      expect(repo.resets, 1);
      pending.complete();
      await first;
      expect(repo.password, ' Abc123! ');
      expect(repo.token, 'opaque+/%token==');
      expect(cubit.state.status, PasswordRecoveryStatus.resetSucceeded);
      expect(await TokenStorage.getToken(), isNull);
      expect(cleanup, 1);
      await cubit.resetPassword('Abc123!x', 'Abc123!x');
      expect(repo.resets, 1);
    },
  );
  test('late reset success never deletes a newer account session', () async {
    await TokenStorage.saveToken('offline-A');
    final pending = Completer<void>();
    final repo = RecoveryRepository()..onReset = () => pending.future;
    final cubit = PasswordRecoveryCubit(
      repository: repo,
      resetToken: 'offline-token',
    );
    addTearDown(cubit.close);
    final reset = cubit.resetPassword('Abc123!x', 'Abc123!x');
    await tick();
    await TokenStorage.saveToken('offline-B');
    pending.complete();
    await reset;
    expect(await TokenStorage.getToken(), 'offline-B');
  });
  test(
    'missing/invalid link never fabricates token; timeout stays uncertain and does not retry',
    () async {
      final repo = RecoveryRepository();
      final missing = PasswordRecoveryCubit(repository: repo, resetToken: '');
      addTearDown(missing.close);
      await missing.resetPassword('Abc123!x', 'Abc123!x');
      expect(repo.resets, 0);
      expect(missing.state.status, PasswordRecoveryStatus.invalidLink);
      repo.onReset =
          () async =>
              throw const PasswordRecoveryFailure(
                RecoveryFailureKind.invalidLink,
              );
      final invalid = PasswordRecoveryCubit(
        repository: repo,
        resetToken: 'offline',
      );
      addTearDown(invalid.close);
      await invalid.resetPassword('Abc123!x', 'Abc123!x');
      expect(invalid.state.status, PasswordRecoveryStatus.invalidLink);
      repo.onReset =
          () async =>
              throw const PasswordRecoveryFailure(
                RecoveryFailureKind.network,
                uncertain: true,
              );
      final uncertain = PasswordRecoveryCubit(
        repository: repo,
        resetToken: 'offline',
      );
      addTearDown(uncertain.close);
      await uncertain.resetPassword('Abc123!x', 'Abc123!x');
      final count = repo.resets;
      expect(uncertain.state.uncertain, true);
      uncertain.clearErrors();
      await uncertain.resetPassword('Abc123!x', 'Abc123!x');
      expect(repo.resets, count);
    },
  );
  testWidgets('forgot form, generic 202 dialog and close/login navigation', (
    tester,
  ) async {
    final repo = RecoveryRepository();
    await mount(tester, repo);
    await tester.enterText(field(0), 'invalid');
    await tapButton(tester, 'Gửi yêu cầu khôi phục');
    expect(find.text('Vui lòng nhập địa chỉ email hợp lệ.'), findsOneWidget);
    expect(repo.requests, 0);
    await tester.enterText(field(0), ' camera@example.org ');
    await tapButton(tester, 'Gửi yêu cầu khôi phục');
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra hộp thư của bạn'), findsOneWidget);
    expect(find.textContaining('Nếu email phù hợp'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(repo.requests, 1);
    await tapButton(tester, 'Gửi yêu cầu khôi phục');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Quay lại đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN_FIXTURE'), findsOneWidget);
  });
  testWidgets(
    'loading is announced, disables form and blocks duplicate keyboard/button submit',
    (tester) async {
      final repo = RecoveryRepository();
      final pending = Completer<void>();
      repo.onRequest = () => pending.future;
      await mount(tester, repo);
      await tester.enterText(field(0), 'camera@example.org');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.requests, 1);
      expect(tester.widget<TextField>(field(0)).enabled, false);
      expect(
        find.bySemanticsLabel('Đang xử lý yêu cầu…. Đang xử lý'),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(button.onPressed, isNull);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Kiểm tra hộp thư của bạn'), findsOneWidget);
    },
  );
  testWidgets(
    'network failure retry requires user action; cancel never sends',
    (tester) async {
      final repo =
          RecoveryRepository()
            ..onRequest =
                () async =>
                    throw const PasswordRecoveryFailure(
                      RecoveryFailureKind.network,
                      uncertain: true,
                    );
      await mount(tester, repo);
      await tester.enterText(field(0), 'camera@example.org');
      await tapButton(tester, 'Gửi yêu cầu khôi phục');
      await tester.pumpAndSettle();
      expect(find.text('Chưa thể gửi yêu cầu'), findsOneWidget);
      expect(repo.requests, 1);
      await tester.tap(find.text('Hủy bỏ'));
      await tester.pumpAndSettle();
      expect(repo.requests, 1);
      await tapButton(tester, 'Gửi yêu cầu khôi phục');
      await tester.pumpAndSettle();
      repo.onRequest = null;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Thử lại'));
      await tester.pumpAndSettle();
      expect(repo.requests, 3);
      expect(find.text('Kiểm tra hộp thư của bạn'), findsOneWidget);
    },
  );
  testWidgets(
    'reset obscures independently, validates, clears form on 204 and returns login',
    (tester) async {
      final repo = RecoveryRepository();
      await mount(tester, repo, reset: true);
      expect(tester.widget<TextField>(field(0)).obscureText, true);
      expect(tester.widget<TextField>(field(1)).obscureText, true);
      expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
      await tester.tap(find.byTooltip('Hiện mật khẩu').first);
      await tester.pump();
      expect(tester.widget<TextField>(field(0)).obscureText, false);
      expect(tester.widget<TextField>(field(1)).obscureText, true);
      await tester.enterText(field(0), 'Abc123!x');
      await tester.enterText(field(1), 'mismatch');
      await tapButton(tester, 'Cập nhật mật khẩu');
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(repo.resets, 0);
      await tester.enterText(field(1), 'Abc123!x');
      await tapButton(tester, 'Cập nhật mật khẩu');
      await tester.pumpAndSettle();
      expect(repo.resets, 1);
      expect(find.text('Đặt lại mật khẩu thành công'), findsOneWidget);
      expect(tester.widget<TextField>(field(0)).controller!.text, isEmpty);
      await tester.tap(
        find.widgetWithText(TextButton, 'Quay lại đăng nhập').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('LOGIN_FIXTURE'), findsOneWidget);
    },
  );
  testWidgets(
    'invalid link opens new request flow; real router accepts internal extra without decoding',
    (tester) async {
      final repo =
          RecoveryRepository()
            ..onReset =
                () async =>
                    throw const PasswordRecoveryFailure(
                      RecoveryFailureKind.invalidLink,
                    );
      await mount(tester, repo, reset: true);
      await tester.enterText(field(0), 'Abc123!x');
      await tester.enterText(field(1), 'Abc123!x');
      await tapButton(tester, 'Cập nhật mật khẩu');
      await tester.pumpAndSettle();
      expect(
        find.text('Liên kết không hợp lệ hoặc đã hết hạn'),
        findsOneWidget,
      );
      await tapButton(tester, 'Yêu cầu liên kết mới');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'Email đã đăng ký',
        ),
        findsOneWidget,
      );
      final router = AppRouter.createRouter(
        initialLocation: AppRouter.resetPassword,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(
        find.text('Liên kết không hợp lệ hoặc đã hết hạn'),
        findsOneWidget,
      );
      router.go(
        AppRouter.resetPassword,
        extra: const PasswordResetArguments('opaque+/%token=='),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'Mật khẩu mới',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('opaque'), findsNothing);
    },
  );
  testWidgets(
    'reset timeout presents uncertain outcome and new-link route without retrying',
    (tester) async {
      final repo =
          RecoveryRepository()
            ..onReset =
                () async =>
                    throw const PasswordRecoveryFailure(
                      RecoveryFailureKind.network,
                      uncertain: true,
                    );
      await mount(tester, repo, reset: true);
      await tester.enterText(field(0), 'Abc123!x');
      await tester.enterText(field(1), 'Abc123!x');
      await tapButton(tester, 'Cập nhật mật khẩu');
      await tester.pumpAndSettle();
      expect(find.text('Cần kiểm tra kết quả'), findsOneWidget);
      expect(repo.resets, 1);
      expect(find.textContaining('Chưa xác định được kết quả'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Yêu cầu liên kết mới'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is AppTextField && w.label == 'Email đã đăng ký',
        ),
        findsOneWidget,
      );
      expect(repo.resets, 1);
      expect(repo.requests, 0);
    },
  );
  testWidgets('small screen, keyboard and large text fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    for (final reset in [false, true]) {
      await mount(tester, RecoveryRepository(), reset: reset, scale: 2);
      await tester.ensureVisible(field(0));
      await tester.tap(field(0));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(
          ElevatedButton,
          reset ? 'Cập nhật mật khẩu' : 'Gửi yêu cầu khôi phục',
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.view.resetViewInsets();
    }
  });
}
