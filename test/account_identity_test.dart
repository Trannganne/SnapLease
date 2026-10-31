import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/core/storage/token_storage.dart';
import 'package:rentcam/core/widgets/user_avatar.dart';
import 'package:rentcam/domain/entities/customer_profile.dart';
import 'package:rentcam/features/account/presentation/bloc/account_cubit.dart';
import 'package:rentcam/features/auth/data/auth_repository.dart';
import 'package:rentcam/features/identity_verification/bloc/identity_verification_bloc.dart';
import 'package:rentcam/features/identity_verification/bloc/identity_verification_event.dart';
import 'package:rentcam/features/identity_verification/bloc/identity_verification_state.dart';
import 'package:rentcam/features/identity_verification/data/identity_verification_repository.dart';
import 'package:rentcam/features/identity_verification/services/identity_scanner.dart';
import 'package:rentcam/features/identity_verification/presentation/identity_verification_page.dart';
import 'package:rentcam/features/rental/bloc/rental_bloc.dart';

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 15));
XFile photo(List<int> bytes) => XFile.fromData(Uint8List.fromList(bytes));
Dio offline(FutureOr<Object?> Function(RequestOptions) handle) {
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
        } catch (_) {
          handler.reject(
            DioException(
              requestOptions: request,
              type: DioExceptionType.connectionError,
            ),
          );
        }
      },
    ),
  );
  return dio;
}

Map<String, Object?> me(String username, {String role = 'KHACH_HANG'}) => {
  'maTaiKhoan': 'A-$username',
  'tenDangNhap': username,
  'vaiTro': role,
  'maKhachThue': role == 'KHACH_HANG' ? 'K-$username' : null,
};
Map<String, Object?> profile() => {
  'hoTen': 'Tên khác username',
  'email': 'offline@example.invalid',
  'soDienThoai': '0000000000',
  'daXacNhanThongTin': true,
};

class Scanner extends IdentityScanner {
  Future<ExtractedIdentityData> Function()? result;
  @override
  Future<ExtractedIdentityData> scanBothSides(
    File front,
    File back, {
    String? manuallyScannedQr,
  }) async => result == null ? extracted() : result!();
  @override
  void dispose() {}
}

ExtractedIdentityData extracted() => ExtractedIdentityData(
  cccd: IdentityField('OFFLINE_ID', 'OCR'),
  hoTen: IdentityField('Offline name', 'OCR'),
  ngaySinh: IdentityField('1990-01-01', 'OCR'),
  gioiTinh: IdentityField('NAM', 'OCR'),
  quocTich: IdentityField('VN', 'OCR'),
  diaChiThuongTru: IdentityField('Offline address', 'OCR'),
  ngayCap: IdentityField('2020-01-01', 'OCR'),
  noiCap: IdentityField('Offline issuer', 'OCR'),
);

class IdentityRepo extends IdentityVerificationRepository {
  bool failConfirmation = false;
  int uploads = 0, confirmations = 0;
  Future<String> Function()? upload;
  bool savedConfirmed = true;
  @override
  Future<CustomerProfile> getCustomerProfile({String? sessionToken}) async =>
      CustomerProfile.fromJson({
        ...profile(),
        'cccd': 'OFFLINE_ID',
        'daXacNhanThongTin': savedConfirmed,
      });
  @override
  Future<
    ({
      CustomerProfile profile,
      String? documentId,
      String? documentNumber,
      String? status,
      bool hasImages,
      bool matchesProfile,
    })
  >
  getSavedIdentity({String? sessionToken}) async => (
    profile: CustomerProfile.fromJson({
      ...profile(),
      'cccd': 'OFFLINE_ID',
      'ngaySinh': '1990-01-01',
      'ngayCap': '2020-01-01',
      'daXacNhanThongTin': savedConfirmed,
    }),
    documentId: 'OFFLINE_DOC',
    documentNumber: 'OFFLINE_ID',
    status: 'CHO_XAC_MINH',
    hasImages: true,
    matchesProfile: savedConfirmed,
  );
  @override
  Future<String> uploadIdentityDocuments({
    required XFile frontImage,
    required XFile backImage,
    required String cccd,
    required String hoTen,
    String? sessionToken,
  }) async {
    uploads++;
    return upload == null ? 'OFFLINE_DOC' : upload!();
  }

  @override
  Future<void> confirmIdentity({
    required String maGiayTo,
    required ExtractedIdentityData data,
    String? sessionToken,
  }) async {
    confirmations++;
    if (failConfirmation) {
      throw const IdentityRequestFailure('Offline confirmation failed');
    }
    savedConfirmed = true;
  }
}

class CancelPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => null;
}

class LargeImage extends XFile {
  LargeImage() : super('offline-too-large');
  @override
  Future<int> length() async => 10 * 1024 * 1024 + 1;
}

class Rental extends RentalBloc {
  Rental(IdentityVerificationRepository repo) : super(identityRepository: repo);
  void show(RentalState value) => emit(value);
  @override
  void add(RentalEvent event) {
    if (event is CheckReservationStatus || event is FetchActiveReservation) {
      return;
    }
    super.add(event);
  }
}

Future<void> prepare(IdentityVerificationBloc bloc) async {
  bloc.add(const SetFrontImage('offline-front'));
  bloc.add(const SetBackImage('offline-back'));
  bloc.add(const ToggleConsent(true));
  await tick();
  bloc.add(SubmitVerification());
  await tick();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({'access_token': 'offline-A'}),
  );
  test(
    'existing pending document is read before capture; confirmation reuses its ID and leaves approval pending',
    () async {
      final repo = IdentityRepo()..savedConfirmed = false;
      final bloc = IdentityVerificationBloc(
        scanner: Scanner(),
        repository: repo,
      );
      addTearDown(bloc.close);
      bloc.add(const LoadSavedIdentity());
      await tick();
      expect(bloc.state.savedDocumentStatus, 'CHO_XAC_MINH');
      await prepare(bloc);
      bloc.add(ConfirmVerification());
      await tick();
      expect(repo.uploads, 0);
      expect(repo.confirmations, 1);
      expect(bloc.state.status, IdentityVerificationStatus.verificationSuccess);
      expect(bloc.state.savedProfile?.daXacNhanThongTin, true);
      expect(bloc.state.savedDocumentStatus, 'CHO_XAC_MINH');
    },
  );
  test(
    'upload preserves known 409 business error and does not expose arbitrary bodies',
    () async {
      for (final message in [
        'Số giấy tờ đã được sử dụng bởi khách thuê khác.',
        'private untrusted response',
      ]) {
        final dio =
            Dio()
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest:
                      (r, h) => h.reject(
                        DioException(
                          requestOptions: r,
                          response: Response(
                            requestOptions: r,
                            statusCode: 409,
                            data: {'loi': message},
                          ),
                          type: DioExceptionType.badResponse,
                        ),
                      ),
                ),
              );
        final repo = IdentityVerificationRepository(dio: dio);
        await expectLater(
          repo.uploadIdentityDocuments(
            frontImage: photo([1, 2]),
            backImage: photo([3, 4]),
            cccd: 'OFFLINE_ID',
            hoTen: 'Offline',
          ),
          throwsA(
            isA<IdentityRequestFailure>().having(
              (e) => e.message,
              'safe message',
              message.startsWith('Số')
                  ? message
                  : 'Không thể tải giấy tờ (HTTP 409). Vui lòng thử lại.',
            ),
          ),
        );
      }
    },
  );
  test(
    'upload uses JSON data URIs for both images and confirmation preserves ISO dates',
    () async {
      final requests = <RequestOptions>[];
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (r, h) {
                  requests.add(r);
                  h.resolve(
                    Response(
                      requestOptions: r,
                      statusCode: r.path == '/api/giay-to' ? 201 : 200,
                      data:
                          r.path == '/api/giay-to'
                              ? {'maGiayTo': 'OFFLINE_DOC'}
                              : {'success': true},
                    ),
                  );
                },
              ),
            );
      final repo = IdentityVerificationRepository(dio: dio);
      expect(
        await repo.uploadIdentityDocuments(
          frontImage: photo([1, 2]),
          backImage: photo([3, 4]),
          cccd: 'OFFLINE_ID',
          hoTen: 'Offline',
        ),
        'OFFLINE_DOC',
      );
      await repo.confirmIdentity(
        maGiayTo: 'OFFLINE_DOC',
        data: extracted(),
        sessionToken: 'offline-A',
      );
      expect(requests[0].contentType, Headers.jsonContentType);
      expect(requests[0].data['MatTruocUrl'], 'data:image/jpeg;base64,AQI=');
      expect(requests[0].data['MatSauUrl'], 'data:image/jpeg;base64,AwQ=');
      expect(requests[1].data['NgaySinh'], '1990-01-01');
      expect(requests[1].data['NgayCap'], '2020-01-01');
    },
  );
  test(
    'uncertain upload performs only readback and never reports a matching number as upload success',
    () async {
      final methods = <String>[];
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (r, h) {
                  methods.add(r.method);
                  if (r.method == 'POST') {
                    h.reject(
                      DioException(
                        requestOptions: r,
                        type: DioExceptionType.receiveTimeout,
                      ),
                    );
                    return;
                  }
                  h.resolve(
                    Response(
                      requestOptions: r,
                      statusCode: 200,
                      data:
                          r.path == '/api/khach-thue/cua-toi'
                              ? profile()
                              : [
                                {
                                  'maGiayTo': 'OFFLINE_DOC',
                                  'soGiayTo': 'OFFLINE_ID',
                                  'loaiGiayTo': 'CCCD',
                                  'trangThaiXacMinh': 'CHO_XAC_MINH',
                                },
                              ],
                    ),
                  );
                },
              ),
            );
      await expectLater(
        IdentityVerificationRepository(dio: dio).uploadIdentityDocuments(
          frontImage: photo([1]),
          backImage: photo([2]),
          cccd: 'OFFLINE_ID',
          hoTen: 'Offline',
        ),
        throwsA(
          isA<IdentityRequestFailure>().having(
            (e) => e.uncertain,
            'unknown upload',
            true,
          ),
        ),
      );
      expect(methods, ['POST', 'GET', 'GET']);
    },
  );
  test(
    'duplicate email error is rendered through the existing registration contract',
    () async {
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest:
                    (r, h) => h.reject(
                      DioException(
                        requestOptions: r,
                        response: Response(
                          requestOptions: r,
                          statusCode: 409,
                          data: {
                            'code': 'EMAIL_ALREADY_USED',
                            'loi': 'Email đã được sử dụng bởi tài khoản khác.',
                          },
                        ),
                        type: DioExceptionType.badResponse,
                      ),
                    ),
              ),
            );
      await expectLater(
        AuthRepository(dio: dio).register(
          'offline',
          'offline@example.invalid',
          '0000000000',
          'offline',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'business error',
            contains('Email đã được sử dụng bởi tài khoản khác.'),
          ),
        ),
      );
    },
  );
  for (final mode in ['account', 'rental', 'expired']) {
    testWidgets(
      'saved profile context $mode is read-only and preserves the rental selection',
      (tester) async {
        final repo = IdentityRepo();
        final identity = IdentityVerificationBloc(
          scanner: Scanner(),
          repository: repo,
        );
        final rental = Rental(repo);
        addTearDown(identity.close);
        addTearDown(rental.close);
        final start = DateTime(2030, 1, 1), end = DateTime(2030, 1, 2);
        final quote = <String, dynamic>{'tongTienThue': 123};
        rental.show(
          RentalState(
            maGiuCho: 'OFFLINE_HOLD',
            branchId: 'OFFLINE_BRANCH',
            reservedBranchId: 'OFFLINE_BRANCH',
            pickupDate: start,
            reservedPickupDate: start,
            returnDate: end,
            reservedReturnDate: end,
            quantity: 2,
            reservedQuantity: 2,
            priceQuote: quote,
            initialTimeRemaining:
                mode == 'expired' ? Duration.zero : const Duration(minutes: 10),
          ),
        );
        final router = GoRouter(
          initialLocation: '/account',
          routes: [
            GoRoute(
              path: '/account',
              builder:
                  (_, _) => const Scaffold(body: Text('Account destination')),
            ),
            GoRoute(
              path: '/identity',
              builder:
                  (_, _) =>
                      IdentityVerificationView(fromAccount: mode == 'account'),
            ),
            GoRoute(
              path: '/rental-confirmation',
              builder:
                  (_, _) => const Scaffold(body: Text('Rental destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        identity.add(const LoadSavedIdentity());
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: identity),
              BlocProvider<RentalBloc>.value(value: rental),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        router.push('/identity');
        await tester.pumpAndSettle();
        expect(find.text('Thông tin cá nhân & Giấy tờ'), findsOneWidget);
        expect(
          find.text('Đã cập nhật giấy tờ · Chờ nhân viên xác minh'),
          findsOneWidget,
        );
        final button = find.text(
          mode == 'account'
              ? 'Quay lại Tài khoản'
              : 'Tiếp tục xem xác nhận thuê',
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.uploads, 0);
        expect(repo.confirmations, 0);
        if (mode == 'account') {
          expect(find.text('Account destination'), findsOneWidget);
        }
        if (mode == 'rental') {
          expect(find.text('Rental destination'), findsOneWidget);
        }
        if (mode == 'expired') {
          expect(find.text('Rental destination'), findsNothing);
        }
        expect(rental.state.maGiuCho, 'OFFLINE_HOLD');
        expect(rental.state.branchId, 'OFFLINE_BRANCH');
        expect(rental.state.pickupDate, start);
        expect(rental.state.returnDate, end);
        expect(rental.state.quantity, 2);
        expect(rental.state.priceQuote, quote);
      },
    );
  }
  test(
    'cancelled picker preserves a known upload; confirmation retries never re-upload',
    () async {
      final repo = IdentityRepo()..failConfirmation = true;
      final bloc = IdentityVerificationBloc(
        scanner: Scanner(),
        repository: repo,
        imagePicker: CancelPicker(),
      );
      addTearDown(bloc.close);
      await prepare(bloc);
      bloc.add(ConfirmVerification());
      await tick();
      expect(repo.uploads, 1);
      expect(bloc.state.status, IdentityVerificationStatus.confirmError);
      final front = bloc.state.frontImage;
      bloc.add(const PickFrontImage(ImageSource.gallery));
      await tick();
      expect(bloc.state.frontImage, front);
      repo.failConfirmation = false;
      bloc.add(ConfirmVerification());
      await tick();
      expect(repo.uploads, 1);
      expect(repo.confirmations, 2);
    },
  );
  test(
    'OCR errors and blank extracted fields cannot be submitted as valid identity',
    () async {
      final scanner =
          Scanner()..result = () async => throw StateError('offline');
      final repo = IdentityRepo();
      final bloc = IdentityVerificationBloc(scanner: scanner, repository: repo);
      addTearDown(bloc.close);
      await prepare(bloc);
      expect(bloc.state.status, IdentityVerificationStatus.error);
      expect(repo.uploads, 0);
      final data = extracted();
      expect(
        ExtractedIdentityData(
          cccd: data.cccd,
          hoTen: data.hoTen,
          ngaySinh: IdentityField('', 'OCR'),
          gioiTinh: data.gioiTinh,
          quocTich: data.quocTich,
          diaChiThuongTru: data.diaChiThuongTru,
          ngayCap: data.ngayCap,
          noiCap: data.noiCap,
        ).isValid,
        false,
      );
    },
  );
  test(
    'oversized photo is rejected before reading/base64 or sending HTTP',
    () async {
      var calls = 0;
      final repo = IdentityVerificationRepository(
        dio: offline((_) {
          calls++;
          return {};
        }),
      );
      await expectLater(
        repo.uploadIdentityDocuments(
          frontImage: LargeImage(),
          backImage: XFile('offline-back'),
          cccd: 'OFFLINE',
          hoTen: 'Offline',
        ),
        throwsA(isA<IdentityRequestFailure>()),
      );
      expect(calls, 0);
    },
  );
  test(
    'account maps existing endpoints and never derives approval from confirmed info',
    () async {
      final requests = <RequestOptions>[];
      final dio = offline((r) {
        requests.add(r);
        return switch (r.path) {
          '/api/auth/me' => me('trial.username'),
          '/api/khach-thue/cua-toi' => profile(),
          _ => [
            {'trangThaiXacMinh': 'CHO_XAC_MINH'},
            {'trangThaiXacMinh': 'HOP_LE'},
          ],
        };
      });
      final cubit = AccountCubit(
        auth: AuthRepository(dio: dio),
        identity: IdentityVerificationRepository(dio: dio),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.username, 'trial.username');
      expect(cubit.state.avatarLetter, 'T');
      expect(cubit.state.profile?.hoTen, 'Tên khác username');
      expect(cubit.state.profile?.email, 'offline@example.invalid');
      expect(cubit.state.identityLabel, 'Đã cập nhật giấy tờ · Chờ xác minh');
      expect(requests.length, 3);
      expect(
        requests.every(
          (r) =>
              r.method == 'GET' &&
              r.headers['Authorization'] == 'Bearer offline-A' &&
              r.extra[ApiClient.boundSession] == true,
        ),
        true,
      );
    },
  );
  test(
    'missing profile fields are not fabricated; status is server-authoritative',
    () {
      final p = CustomerProfile.fromJson({});
      expect(p.hoTen, '');
      expect(p.email, isNull);
      expect(p.daXacNhanThongTin, false);
      for (final pair
          in {
            'HOP_LE': 'Giấy tờ đã được xác minh',
            'TU_CHOI': 'Giấy tờ bị từ chối',
            'UNKNOWN': 'Chưa xác định trạng thái giấy tờ',
          }.entries) {
        expect(
          AccountState(documentStatus: pair.key).identityLabel,
          pair.value,
        );
      }
      expect(const AccountState().identityLabel, 'Chưa gửi giấy tờ');
    },
  );
  test('admin uses only auth/me and no customer profile', () async {
    final calls = <String>[];
    final dio = offline((r) {
      calls.add(r.path);
      return me('admin', role: 'ADMIN');
    });
    final cubit = AccountCubit(auth: AuthRepository(dio: dio));
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.isCustomer, false);
    expect(cubit.state.profile, isNull);
    expect(calls, ['/api/auth/me']);
  });
  test(
    'late response from previous account cannot restore profile after logout/switch',
    () async {
      final pending = Completer<Object?>();
      final dio = offline(
        (r) =>
            r.headers['Authorization'] == 'Bearer offline-A'
                ? pending.future
                : r.path == '/api/auth/me'
                ? me('new-account', role: 'ADMIN')
                : [],
      );
      final cubit = AccountCubit(
        auth: AuthRepository(dio: dio),
        identity: IdentityVerificationRepository(dio: dio),
      );
      addTearDown(cubit.close);
      final old = cubit.load();
      await tick();
      await TokenStorage.saveToken('offline-B');
      await tick();
      expect(cubit.state.username, 'new-account');
      pending.complete(me('old-account'));
      await old;
      expect(cubit.state.username, 'new-account');
      await TokenStorage.deleteToken();
      expect(cubit.state.profile, isNull);
      expect(cubit.state.username, '');
      await tick();
      expect(cubit.state.error, isNotNull);
    },
  );
  test(
    'out-of-order refresh cannot overwrite a newer read; error can retry',
    () async {
      final first = Completer<Object?>();
      int calls = 0;
      bool fail = false;
      final dio = offline((r) {
        if (fail) throw StateError('offline');
        return ++calls == 1 ? first.future : me('latest', role: 'ADMIN');
      });
      final cubit = AccountCubit(auth: AuthRepository(dio: dio));
      addTearDown(cubit.close);
      final old = cubit.load();
      await tick();
      await cubit.load();
      first.complete(me('stale', role: 'ADMIN'));
      await old;
      expect(cubit.state.username, 'latest');
      fail = true;
      await cubit.load();
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.profile, isNull);
      fail = false;
      await cubit.load();
      expect(cubit.state.username, 'latest');
    },
  );
  testWidgets(
    'username avatar handles spaces, combining marks and emoji safely',
    (tester) async {
      for (final pair
          in {
            '   ': '?',
            'đăng.nhập': 'Đ',
            'a\u0301user': 'A\u0301',
            '👩🏽‍💻user': '👩🏽‍💻',
          }.entries) {
        final state = AccountState(username: pair.key);
        expect(state.avatarLetter, pair.value);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: UserAvatar(displayName: state.avatarLetter)),
          ),
        );
        expect(find.text(pair.value), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        const MaterialApp(home: UserAvatar(displayName: '   ')),
      );
      expect(find.text('U'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'OCR success remains local; confirm is single-flight and uploads once',
    () async {
      final repo = IdentityRepo();
      final pending = Completer<String>();
      repo.upload = () => pending.future;
      final bloc = IdentityVerificationBloc(
        scanner: Scanner(),
        repository: repo,
      );
      addTearDown(bloc.close);
      await prepare(bloc);
      expect(bloc.state.status, IdentityVerificationStatus.success);
      expect(repo.uploads, 0);
      bloc.add(ConfirmVerification());
      bloc.add(ConfirmVerification());
      await tick();
      expect(repo.uploads, 1);
      expect(repo.confirmations, 0);
      pending.complete('OFFLINE_DOC');
      await tick();
      expect(repo.confirmations, 1);
      expect(bloc.state.status, IdentityVerificationStatus.verificationSuccess);
      bloc.add(ConfirmVerification());
      await tick();
      expect(repo.confirmations, 1);
    },
  );
  test(
    'session switch clears documents and stops confirmation of old upload',
    () async {
      final repo = IdentityRepo();
      final pending = Completer<String>();
      repo.upload = () => pending.future;
      final bloc = IdentityVerificationBloc(
        scanner: Scanner(),
        repository: repo,
      );
      addTearDown(bloc.close);
      await prepare(bloc);
      bloc.add(ConfirmVerification());
      await tick();
      await TokenStorage.saveToken('offline-B');
      await tick();
      expect(bloc.state.frontImage, isNull);
      expect(bloc.state.extractedData, isNull);
      pending.complete('OLD_DOC');
      await tick();
      expect(repo.confirmations, 0);
    },
  );
  test('uncertain upload does not blindly create another document', () async {
    final repo =
        IdentityRepo()
          ..upload =
              () async =>
                  throw const IdentityRequestFailure(
                    'Unknown outcome',
                    uncertain: true,
                  );
    final bloc = IdentityVerificationBloc(scanner: Scanner(), repository: repo);
    addTearDown(bloc.close);
    await prepare(bloc);
    bloc.add(ConfirmVerification());
    await tick();
    bloc.add(ConfirmVerification());
    await tick();
    expect(repo.uploads, 1);
    expect(repo.confirmations, 0);
    expect(bloc.state.status, IdentityVerificationStatus.confirmError);
  });
  test('late OCR result is dropped after session switch', () async {
    final result = Completer<ExtractedIdentityData>();
    final scanner = Scanner()..result = () => result.future;
    final bloc = IdentityVerificationBloc(scanner: scanner);
    addTearDown(bloc.close);
    await prepare(bloc);
    await TokenStorage.saveToken('offline-B');
    await tick();
    result.complete(extracted());
    await tick();
    expect(bloc.state.extractedData, isNull);
  });
}
