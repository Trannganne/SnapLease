import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rentcam/core/network/api_client.dart';
import 'package:rentcam/features/contract/data/repositories/contract_repository.dart';
import 'package:rentcam/features/contract/presentation/contract_page.dart';
import 'package:rentcam/features/review/data/review_remote_data_source.dart';
import 'package:rentcam/features/review/data/review_api_dto.dart';
import 'package:rentcam/features/review/data/repositories/dio_review_repository.dart';
import 'package:rentcam/features/review/data/repositories/review_repository.dart';
import 'package:rentcam/features/review/domain/models/review_detail_model.dart';
import 'package:rentcam/features/review/domain/models/review_submission_data.dart';
import 'package:rentcam/features/review/domain/models/review_form.dart';
import 'package:rentcam/features/review/bloc/review_cubit.dart';
import 'package:rentcam/features/review/bloc/review_state.dart';
import 'package:rentcam/features/review/presentation/review_page.dart';
import 'package:rentcam/features/review/presentation/widgets/review_device_picker.dart';
import 'package:rentcam/features/contract/domain/models/handover_models.dart';

Map<String, dynamic> formJson({
  String detail = 'CT1',
  String? existing,
  bool allowed = true,
}) => {
  'maChiTietHopDong': detail,
  'maHopDong': 'HD1',
  'maThietBi': 'TB1',
  'maDongMay': 'DM1',
  'tenDongMay': 'Camera',
  'trangThaiHopDong': 'HOAN_THANH',
  'duocDanhGia': allowed,
  'maDanhGiaDaCo': existing,
  'lyDoKhongTheDanhGia': 'Chưa hoàn tất',
  'gioiHanNhanXet': 12,
  'gioiHanAnh': 2,
  'diemNoiBatMacDinh': [
    {'ma': 'DE_SU_DUNG', 'ten': 'Dễ sử dụng'},
    {'ma': 'PHU_KIEN_DAY_DU', 'ten': 'Phụ kiện đầy đủ'},
  ],
};
Map<String, dynamic> reviewJson({
  String status = 'CONG_KHAI',
  List<Map<String, dynamic>> images = const [],
}) => {
  'maDanhGia': 'DG1',
  'maChiTietHopDong': 'CT1',
  'soSao': 4,
  'nhanXet': 'Rất tốt',
  'hoTenKhachHang': 'Khách từ API',
  'ngayDanhGia': '2026-10-18T10:00:00+07:00',
  'trangThaiKiemDuyet': status,
  'ghiChuKiemDuyet': 'Ghi chú từ API',
  'diemNoiBat': [
    {'ma': 'DE_SU_DUNG', 'ten': 'Dễ sử dụng'},
  ],
  'hinhAnh': images,
  'thietBi': {'chinhHang': true},
};
ReviewDetailModel apiReview([String status = 'CONG_KHAI']) =>
    ReviewApiDto.review(reviewJson(status: status));

Dio fakeHttp(FutureOr<dynamic> Function(RequestOptions) handle) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          handler.resolve(
            Response(
              requestOptions: options,
              data: await handle(options),
              statusCode: options.method == 'POST' ? 201 : 200,
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

DioException failure(RequestOptions o, int status) => DioException(
  requestOptions: o,
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: o,
    statusCode: status,
    data: {'loi': 'Điều kiện nghiệp vụ'},
  ),
);
DioReviewRepository repo(Dio dio) => DioReviewRepository(
  remote: ReviewRemoteDataSource(
    dio: dio,
    session: () async => 'synthetic-session',
  ),
);

class ReviewServer implements ReviewRepository {
  ReviewDetailModel? stored;
  ReviewFailure? readError;
  ReviewFailure? postError;
  bool commitBeforeError = false;
  bool allowed = true;
  int posts = 0, uploads = 0, reads = 0;
  ReviewSubmissionData? lastSubmission;
  int? failUploadAt;
  bool uploadUncertain = false;
  Completer<ReviewDetailModel>? postWait;
  final List<Map<String, dynamic>> images = [];
  @override
  Future<ReviewForm> getForm(String detailId) async {
    if (readError != null) throw readError!;
    return ReviewApiDto.form(
      formJson(
        detail: detailId,
        existing: stored?.reviewId,
        allowed: allowed && stored == null,
      ),
      detailId,
    );
  }

  @override
  Future<ReviewDetailModel?> getReviewForContractDetail(String detailId) async {
    reads++;
    if (readError != null) throw readError!;
    return stored;
  }

  @override
  Future<ReviewDetailModel> submitReview(ReviewSubmissionData data) async {
    posts++;
    lastSubmission = data;
    if (postWait != null) return postWait!.future;
    if (postError != null) {
      if (commitBeforeError) stored = apiReview();
      throw postError!;
    }
    return stored = apiReview();
  }

  @override
  Future<({String id, String url})> uploadImage(String id, String path) async {
    uploads++;
    if (uploads == failUploadAt) {
      throw ReviewFailure('Ảnh bị từ chối', uncertain: uploadUncertain);
    }
    final image = {
      'maAnhDanhGia': 'A$uploads',
      'duongDanAnh': 'https://example.test/$uploads.png',
      'thuTu': uploads,
    };
    images.add(image);
    stored = ReviewApiDto.review(reviewJson(images: images));
    return (
      id: image['maAnhDanhGia'] as String,
      url: image['duongDanAnh'] as String,
    );
  }
}

class DelayedReviewServer extends ReviewServer {
  final requests = <String, Completer<ReviewForm>>{};
  @override
  Future<ReviewForm> getForm(String detailId) =>
      (requests[detailId] = Completer<ReviewForm>()).future;
}

class ContractReviewServer extends ContractRepository {
  final int count;
  ContractReviewServer(this.count);
  @override
  Future<Map<String, dynamic>> getContractById(String id) async => {
    'maHopDong': id,
    'trangThai': 'HOAN_THANH',
    'ngayTaoHopDong': '2026-10-01T10:00:00',
    'thoiGianBanGiao': '2026-10-02T10:00:00',
    'thoiGianTraDuKien': '2026-10-03T10:00:00',
    'tongTien': 100000,
    'tongTienCoc': 200000,
    'datTheoDongMay': [
      {'maDongMay': 'DM1', 'tenDongMay': 'Camera', 'soLuong': count},
    ],
    'chiTiet': [
      for (var i = 1; i <= count; i++)
        {
          'maChiTietHopDong': 'CT$i',
          'maThietBi': 'TB$i',
          'maDongMay': 'DM1',
          'soSerial': 'S$i',
        },
    ],
    'thanhToan': [],
    'phuLuc': [],
  };
}

void main() {
  for (final stars in [1, 5]) {
    test('$stars stars publish immediately via real DTO/repository', () async {
      var posts = 0;
      final repository = repo(
        fakeHttp((options) {
          if (options.method == 'POST') {
            posts++;
            expect((options.data as Map)['soSao'], stars);
            return {
              ...reviewJson(),
              'soSao': stars,
              'trangThaiHienThi': 'CONG_KHAI',
            };
          }
          return formJson();
        }),
      );
      final cubit = ReviewCubit(repository: repository, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(stars);
      if (stars <= 2) cubit.updateComment('Chưa tốt');
      await cubit.submit();
      expect(posts, 1);
      expect(cubit.state.viewMode, ReviewViewMode.published);
      expect(cubit.state.submittedReview!.rating, stars);
      expect(cubit.state.submittedReview!.isPublic, true);
      expect(cubit.state.submittedReview!.isApproved, false);
    });
  }
  test(
    'explicit visibility publishes legacy null, missing or unknown visibility never implies public',
    () {
      final legacy = {
        ...reviewJson(),
        'trangThaiKiemDuyet': null,
        'trangThaiHienThi': 'CONG_KHAI',
      };
      expect(ReviewApiDto.review(legacy).isPublic, true);
      legacy.remove('trangThaiHienThi');
      expect(ReviewApiDto.review(legacy).isPublic, false);
      expect(
        ReviewApiDto.review({
          ...reviewJson(),
          'trangThaiHienThi': 'NEW_UNKNOWN',
        }).isPublic,
        false,
      );
      expect(
        ReviewApiDto.review({
          ...reviewJson(),
          'trangThaiHienThi': 'AN',
        }).isPublic,
        false,
      );
    },
  );
  testWidgets('submit button stays above the keyboard on a 390px phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final server = ReviewServer();
    await tester.pumpWidget(
      MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Chưa tốt');
    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Gửi đánh giá')).bottom,
      lessThanOrEqualTo(544),
    );
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(server.posts, 1);
  });
  test('pending photos are not sent after moderation changes', () async {
    final server = ReviewServer()..failUploadAt = 1;
    final cubit = ReviewCubit(repository: server, isRemote: true);
    addTearDown(cubit.close);
    await cubit.load('CT1');
    cubit.setRating(4);
    cubit.addImage('local.png');
    await cubit.submit();
    server.stored = apiReview('AN');
    await cubit.reconcileImages(retryPending: true);
    expect(server.uploads, 1);
    expect(server.posts, 1);
    expect(cubit.state.viewMode, ReviewViewMode.hidden);
    expect(cubit.state.errorMessage, contains('không thể thêm ảnh'));
  });
  testWidgets('back is blocked during POST and cannot start another submit', (
    tester,
  ) async {
    final server = ReviewServer()..postWait = Completer<ReviewDetailModel>();
    await tester.pumpWidget(
      MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded).last);
    await tester.pump(); // Rebuild the previously disabled submit button.
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pump();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    expect(server.posts, 1);
    expect(find.text('Bỏ thay đổi?'), findsNothing);
    expect(find.byType(ReviewPage), findsOneWidget);
    server.stored = apiReview();
    server.postWait!.complete(server.stored!);
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi đánh giá'), findsOneWidget);
  });
  test('production data source reuses the bearer-enabled ApiClient', () {
    expect(identical(ReviewRemoteDataSource().dio, ApiClient.instance), true);
  });
  test(
    'late form response for an old detail cannot overwrite the current detail',
    () async {
      final server = DelayedReviewServer();
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      final first = cubit.load('CT1');
      final second = cubit.load('CT2');
      server.requests['CT2']!.complete(
        ReviewApiDto.form(formJson(detail: 'CT2'), 'CT2'),
      );
      await second;
      server.requests['CT1']!.complete(ReviewApiDto.form(formJson(), 'CT1'));
      await first;
      expect(cubit.state.targetDevice!.detailId, 'CT2');
    },
  );
  test(
    'successful HTTP with a malformed create response requires reconciliation',
    () async {
      final repository = repo(
        fakeHttp((o) => {...reviewJson(), 'trangThaiKiemDuyet': 99}),
      );
      await expectLater(
        repository.submitReview(
          const ReviewSubmissionData(detailId: 'CT1', rating: 4),
        ),
        throwsA(
          isA<ReviewFailure>().having((e) => e.uncertain, 'uncertain', true),
        ),
      );
    },
  );
  testWidgets(
    'changing route detail clears the previous draft and reloads without extra',
    (tester) async {
      final server = ReviewServer();
      await tester.pumpWidget(
        MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old draft');
      await tester.pumpWidget(
        MaterialApp(home: ReviewPage(detailId: 'CT2', repository: server)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('0/12'), findsOneWidget);
    },
  );
  for (final count in [1, 2]) {
    testWidgets(
      'completed contract with $count assigned devices opens the chosen review detail',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/contract/HD1',
          routes: [
            GoRoute(
              path: '/contract/:id',
              builder:
                  (context, state) => ContractPage(
                    contractId: state.pathParameters['id']!,
                    repository: ContractReviewServer(count),
                  ),
            ),
            GoRoute(
              path: '/review/:id',
              builder:
                  (context, state) => Scaffold(
                    body: Text('review:${state.pathParameters['id']}'),
                  ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Đánh giá'));
        await tester.pumpAndSettle();
        if (count == 2) {
          expect(find.byType(ReviewDevicePicker), findsOneWidget);
          await tester.tap(
            find.descendant(
              of: find.byType(ReviewDevicePicker),
              matching: find.text('Serial: S2'),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(
          find.text(count == 1 ? 'review:CT1' : 'review:CT2'),
          findsOneWidget,
        );
      },
    );
  }
  test(
    'DTO form uses server limits/catalog; hides accessory; API status is authoritative',
    () {
      final form = ReviewApiDto.form(formJson(), 'CT1');
      expect(form.commentLimit, 12);
      expect(form.imageLimit, 2);
      expect(form.highlights.map((x) => x.id), ['DE_SU_DUNG']);
      expect(apiReview().reviewerName, 'Khách từ API');
      expect(apiReview().isVerifiedRenter, false);
      expect(apiReview('UNRECOGNIZED').isApproved, false);
      expect(
        () => ReviewApiDto.review({'reviewId': 'EnglishFixture'}),
        throwsFormatException,
      );
    },
  );
  test(
    'repository sends exact JSON codes, returns server review, uses existing list endpoint',
    () async {
      final seen = <RequestOptions>[];
      final repository = repo(
        fakeHttp((o) {
          seen.add(o);
          return o.method == 'POST' ? reviewJson() : [reviewJson()];
        }),
      );
      final review = await repository.submitReview(
        const ReviewSubmissionData(
          detailId: 'CT1',
          rating: 4,
          comment: '  Tốt  ',
          highlights: ['DE_SU_DUNG'],
        ),
      );
      expect(review.reviewId, 'DG1');
      expect(review.reviewedAt.year, 2026);
      expect(seen.single.data, {
        'maChiTietHopDong': 'CT1',
        'soSao': 4,
        'nhanXet': 'Tốt',
        'diemNoiBat': ['DE_SU_DUNG'],
      });
      expect(
        (await repository.getReviewForContractDetail('CT1'))!.reviewId,
        'DG1',
      );
      expect(seen.last.path, '/api/danh-gia/cua-toi');
    },
  );
  for (final status in [403, 404, 409]) {
    test('HTTP $status remains an error; never returns mock data', () async {
      final repository = repo(fakeHttp((o) => throw failure(o, status)));
      await expectLater(
        repository.getForm('CT1'),
        throwsA(isA<ReviewFailure>().having((e) => e.status, 'status', status)),
      );
    });
  }
  test('POST timeout is uncertain and is not retried by repository', () async {
    var calls = 0;
    final repository = repo(
      fakeHttp((o) {
        calls++;
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        );
      }),
    );
    await expectLater(
      repository.submitReview(
        const ReviewSubmissionData(detailId: 'CT1', rating: 4),
      ),
      throwsA(
        isA<ReviewFailure>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
    expect(calls, 1);
  });
  test(
    'multipart uploads only anh with correct MIME and no JSON content type',
    () async {
      final directory = await Directory.systemTemp.createTemp('review-test');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.png');
      await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
      final repository = repo(
        fakeHttp((o) {
          expect(o.path, '/api/danh-gia/DG1/anh');
          expect(o.contentType, 'multipart/form-data');
          final form = o.data as FormData;
          expect(form.files.single.key, 'anh');
          expect(form.fields, isEmpty);
          expect(form.files.single.value.contentType.toString(), 'image/png');
          return {
            'maAnhDanhGia': 'A1',
            'duongDanAnh': 'https://example.test/1.png',
            'thuTu': 1,
          };
        }),
      );
      expect((await repository.uploadImage('DG1', file.path)).id, 'A1');
    },
  );
  test(
    'repository drops response if the session changed during request',
    () async {
      var session = 'old';
      final remote = ReviewRemoteDataSource(
        session: () async => session,
        dio: fakeHttp((o) {
          session = 'new';
          return formJson();
        }),
      );
      await expectLater(
        remote.request('/unused-fake'),
        throwsA(isA<ReviewFailure>().having((e) => e.status, 'status', 401)),
      );
    },
  );
  test(
    'loading error never exposes blank editable form; retry reloads actual route id',
    () async {
      final server =
          ReviewServer()
            ..readError = const ReviewFailure('API chưa sẵn sàng', status: 404);
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      expect(cubit.state.targetDevice, null);
      expect(cubit.state.canSubmit, false);
      expect(cubit.state.loadError, contains('chưa sẵn sàng'));
      server.readError = null;
      await cubit.retryLoad();
      expect(cubit.state.targetDevice!.detailId, 'CT1');
      cubit.updateComment('abcdefghijklmnop');
      expect(cubit.state.comment.length, 12);
      cubit.toggleHighlightChip('english-fixture-id');
      expect(cubit.state.selectedChips, isEmpty);
    },
  );
  for (final entry
      in {
        'CHO_DUYET': ReviewViewMode.unknown,
        'CONG_KHAI': ReviewViewMode.published,
        'AN': ReviewViewMode.hidden,
        'DA_DUYET': ReviewViewMode.published,
        'TU_CHOI': ReviewViewMode.hidden,
        'UNKNOWN': ReviewViewMode.unknown,
      }.entries) {
    test('existing ${entry.key} is read-only and correctly mapped', () async {
      final server = ReviewServer()..stored = apiReview(entry.key);
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      expect(cubit.state.viewMode, entry.value);
      cubit.setRating(5);
      await cubit.submit();
      expect(server.posts, 0);
      expect(cubit.state.submittedReview!.reviewId, 'DG1');
    });
  }
  test(
    'double submit produces only one POST and uses server identity',
    () async {
      final server = ReviewServer()..postWait = Completer<ReviewDetailModel>();
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      final pending = cubit.submit();
      await cubit.submit();
      expect(server.posts, 1);
      server.stored = apiReview();
      server.postWait!.complete(server.stored!);
      await pending;
      expect(cubit.state.submittedReview!.reviewId, 'DG1');
    },
  );
  test(
    'timeout after commit reconciles without repeating POST or uploading local photos',
    () async {
      final server =
          ReviewServer()
            ..postError = const ReviewFailure('timeout', uncertain: true)
            ..commitBeforeError = true;
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      cubit.addImage('local.png');
      await cubit.submit();
      expect(cubit.state.submittedReview!.reviewId, 'DG1');
      await cubit.submit();
      expect(server.posts, 1);
      expect(server.uploads, 0);
      expect(cubit.state.uploads.single.status, ReviewUploadStatus.pending);
    },
  );
  test('failed reconciliation keeps draft and prevents another POST', () async {
    final server = ReviewServer();
    final cubit = ReviewCubit(repository: server, isRemote: true);
    addTearDown(cubit.close);
    await cubit.load('CT1');
    cubit.setRating(4);
    cubit.updateComment('draft');
    server.postError = const ReviewFailure('timeout', uncertain: true);
    server.readError = const ReviewFailure('offline');
    await cubit.submit();
    await cubit.submit();
    expect(cubit.state.uncertainCreate, true);
    expect(cubit.state.comment, 'draft');
    expect(server.posts, 1);
  });
  test(
    '409 not completed is not falsely treated as an existing review',
    () async {
      final server = ReviewServer();
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      server.allowed = false;
      server.postError = const ReviewFailure('Chưa hoàn tất', status: 409);
      await cubit.submit();
      expect(cubit.state.submittedReview, null);
      expect(cubit.state.canSubmit, false);
      expect(cubit.state.errorMessage, 'Chưa hoàn tất');
    },
  );
  test(
    'partial image error retains review, retries only pending image after reconciliation',
    () async {
      final server = ReviewServer()..failUploadAt = 2;
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      cubit.addImage('1.png');
      cubit.addImage('2.png');
      await cubit.submit();
      expect(cubit.state.submittedReview!.reviewId, 'DG1');
      expect(cubit.state.uploads.map((e) => e.status), [
        ReviewUploadStatus.uploaded,
        ReviewUploadStatus.pending,
      ]);
      expect(cubit.state.formStatus, ReviewFormStatus.failure);
      final before = server.reads;
      await cubit.reconcileImages(retryPending: true);
      expect(server.reads, greaterThan(before));
      expect(server.posts, 1);
      expect(server.uploads, 3);
      expect(cubit.state.submittedReview!.imageUrls, hasLength(2));
    },
  );
  test(
    'image timeout remains uncertain even after refreshing server URLs, never blindly retried',
    () async {
      final server =
          ReviewServer()
            ..failUploadAt = 1
            ..uploadUncertain = true;
      final cubit = ReviewCubit(repository: server, isRemote: true);
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      cubit.addImage('1.png');
      await cubit.submit();
      await cubit.reconcileImages(retryPending: true);
      expect(server.uploads, 1);
      expect(cubit.state.uploads.single.status, ReviewUploadStatus.uncertain);
      expect(cubit.state.errorMessage, contains('không tải lại mù'));
    },
  );
  test(
    'session change clears review and invalidates an outstanding POST response',
    () async {
      final sessions = StreamController<void>.broadcast(sync: true);
      addTearDown(sessions.close);
      final server = ReviewServer()..postWait = Completer<ReviewDetailModel>();
      final cubit = ReviewCubit(
        repository: server,
        isRemote: true,
        sessionChanges: sessions.stream,
      );
      addTearDown(cubit.close);
      await cubit.load('CT1');
      cubit.setRating(4);
      final pending = cubit.submit();
      sessions.add(null);
      server.postWait!.complete(apiReview());
      await pending;
      expect(cubit.state.submittedReview, null);
      expect(cubit.state.targetDevice, null);
      expect(cubit.state.loadError, contains('Phiên đăng nhập'));
    },
  );
  testWidgets(
    'remote form: first tap on chip closes keyboard and selects; submit works with keyboard open',
    (tester) async {
      final server = ReviewServer();
      await tester.pumpWidget(
        MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'draft');
      await tester.ensureVisible(find.text('Dễ sử dụng'));
      await tester.tap(find.text('Dễ sử dụng'));
      await tester.pumpAndSettle();
      // The root focus scope may still have focus; the editable must lose it.
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        false,
      );
      expect(field.controller!.text, 'draft');
      await tester.ensureVisible(find.byType(TextField));
      await tester.showKeyboard(find.byType(TextField));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(server.posts, 1);
      expect(server.lastSubmission!.highlights, ['DE_SU_DUNG']);
      expect(find.text('Đã gửi đánh giá'), findsOneWidget);
    },
  );
  testWidgets('multiple devices select the real detail id independently', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewDevicePicker(
            models: const [
              BookedContractDevice(
                modelId: 'DM',
                name: 'Camera',
                quantity: 2,
                pricePerDay: 1,
              ),
            ],
            devices: const [
              AssignedContractDevice(
                detailId: 'FIRST',
                deviceId: 'T1',
                modelId: 'DM',
                serial: 'S1',
              ),
              AssignedContractDevice(
                detailId: 'SECOND',
                deviceId: 'T2',
                modelId: 'DM',
                serial: 'S2',
              ),
            ],
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Serial: S2'));
    expect(selected, 'SECOND');
    await tester.tap(find.text('Serial: S1'));
    expect(selected, 'FIRST');
  });
  testWidgets('rejected review shows note, no resubmit or false approval', (
    tester,
  ) async {
    final server = ReviewServer()..stored = apiReview('TU_CHOI');
    await tester.pumpWidget(
      MaterialApp(home: ReviewPage(detailId: 'CT1', repository: server)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá đã bị ẩn'), findsOneWidget);
    expect(find.text('Ghi chú từ API'), findsOneWidget);
    expect(find.text('Gửi đánh giá'), findsNothing);
    expect(find.text('Chính hãng'), findsNothing);
  });
}
