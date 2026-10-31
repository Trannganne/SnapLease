import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/features/review/bloc/review_cubit.dart';
import 'package:rentcam/features/review/bloc/review_state.dart';
import 'package:rentcam/features/review/data/repositories/mock_review_repository.dart';
import 'package:rentcam/features/review/data/review_fixtures.dart';
import 'package:rentcam/features/review/domain/models/review_highlight_chip.dart';
import 'package:rentcam/features/review/domain/models/review_target_device.dart';
import 'package:rentcam/features/review/presentation/review_page.dart';
import 'package:rentcam/features/review/presentation/review_preview_page.dart';
import 'package:rentcam/features/review/presentation/widgets/review_approved_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_comment_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_device_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_guideline_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_highlights_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_images_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_pending_card.dart';
import 'package:rentcam/features/review/presentation/widgets/review_star_rating_card.dart';

void main() {
  group('ReviewCubit Unit Tests', () {
    late MockReviewRepository repository;
    late ReviewCubit cubit;

    setUp(() {
      repository = MockReviewRepository(simulatedDelay: Duration.zero);
      cubit = ReviewCubit(
        repository: repository,
        initialDevice: ReviewFixtures.defaultDevice,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'Initial state has 0 stars, empty comment, and canSubmit == false',
      () {
        expect(cubit.state.rating, 0);
        expect(cubit.state.comment, '');
        expect(cubit.state.selectedChips, isEmpty);
        expect(cubit.state.imagePaths, isEmpty);
        expect(cubit.state.canSubmit, isFalse);
        expect(cubit.state.hasUserModified, isFalse);
        expect(cubit.state.viewMode, ReviewViewMode.inputForm);
      },
    );

    test(
      'Setting rating to 1..5 updates rating, hasUserModified and canSubmit',
      () {
        cubit.setRating(5);
        expect(cubit.state.rating, 5);
        expect(cubit.state.canSubmit, isTrue);
        expect(cubit.state.hasUserModified, isTrue);

        cubit.setRating(2);
        expect(cubit.state.rating, 2);
        expect(cubit.state.canSubmit, isTrue);

        // Invalid ratings are ignored
        cubit.setRating(0);
        expect(cubit.state.rating, 2);
        cubit.setRating(6);
        expect(cubit.state.rating, 2);
      },
    );

    test('Updating comment truncates at 500 characters', () {
      cubit.updateComment('Dịch vụ tốt');
      expect(cubit.state.comment, 'Dịch vụ tốt');
      expect(cubit.state.commentLength, 11);

      final over500 = 'a' * 550;
      cubit.updateComment(over500);
      expect(cubit.state.commentLength, 500);
    });

    test('Toggling highlight chips adds/removes labels correctly', () {
      cubit.toggleHighlightChip('Chất lượng hình ảnh tốt');
      expect(cubit.state.selectedChips, contains('Chất lượng hình ảnh tốt'));

      cubit.toggleHighlightChip('Pin sử dụng tốt');
      expect(cubit.state.selectedChips.length, 2);

      cubit.toggleHighlightChip('Chất lượng hình ảnh tốt');
      expect(
        cubit.state.selectedChips,
        isNot(contains('Chất lượng hình ảnh tốt')),
      );
      expect(cubit.state.selectedChips.length, 1);
    });

    test('Options strictly exclude accessories chip', () {
      final labels = ReviewHighlightChip.defaultLabels;
      expect(labels, isNot(contains('Phụ kiện đầy đủ')));
      expect(labels.length, 5);
    });

    test('Adding and removing images honors max 4 images', () {
      cubit.addImage('path1.jpg');
      cubit.addImage('path2.jpg');
      cubit.addImage('path3.jpg');
      cubit.addImage('path4.jpg');
      expect(cubit.state.imagePaths.length, 4);
      expect(cubit.state.canAddImage, isFalse);

      // Attempt 5th image
      cubit.addImage('path5.jpg');
      expect(cubit.state.imagePaths.length, 4);

      // Remove index 1
      cubit.removeImageAt(1);
      expect(cubit.state.imagePaths.length, 3);
      expect(cubit.state.imagePaths, ['path1.jpg', 'path3.jpg', 'path4.jpg']);
      expect(cubit.state.canAddImage, isTrue);
    });

    test('Submit success updates submittedReview and marks success', () async {
      cubit.setRating(5);
      cubit.updateComment('Máy chụp rất đẹp');
      cubit.toggleHighlightChip('Thiết bị hoạt động ổn định');

      await cubit.submit();

      expect(cubit.state.formStatus, ReviewFormStatus.success);
      expect(cubit.state.submittedReview, isNotNull);
      expect(cubit.state.submittedReview!.rating, 5);
      expect(cubit.state.submittedReview!.comment, 'Máy chụp rất đẹp');
    });

    test(
      'Submit failure retains all user inputs and emits error message',
      () async {
        repository.shouldFailSubmission = true;
        repository.failureErrorMessage = 'Mất kết nối máy chủ';

        cubit.setRating(4);
        cubit.updateComment('Bình luận cần giữ lại');
        cubit.addImage('photo.jpg');

        await cubit.submit();

        expect(cubit.state.formStatus, ReviewFormStatus.failure);
        expect(cubit.state.errorMessage, 'Mất kết nối máy chủ');
        // Verify inputs preserved
        expect(cubit.state.rating, 4);
        expect(cubit.state.comment, 'Bình luận cần giữ lại');
        expect(cubit.state.imagePaths, ['photo.jpg']);
      },
    );

    test('Submit fails if contract is not completed', () async {
      final uncompletedDevice = const ReviewTargetDevice(
        contractId: 'HD-001',
        detailId: 'CTHD_001',
        deviceId: 'TB_001',
        modelId: 'DM_001',
        modelName: 'Sony A7 IV',
        branchName: 'Chi nhánh 1',
        contractStatus: 'DANG_THUE',
      );
      final uncompletedCubit = ReviewCubit(
        repository: repository,
        initialDevice: uncompletedDevice,
      );

      uncompletedCubit.setRating(5);
      expect(uncompletedCubit.state.canSubmit, isFalse);
      await uncompletedCubit.submit();

      // Submit is guarded by canSubmit and stays in editing mode
      expect(uncompletedCubit.state.formStatus, ReviewFormStatus.editing);
      uncompletedCubit.close();
    });
  });

  group('ReviewPage Widget Tests', () {
    testWidgets(
      'low-star dialog preserves draft and focuses comment without posting',
      (tester) async {
        final repository = MockReviewRepository(simulatedDelay: Duration.zero);
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.defaultDevice,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
        await tester.pump();
        await tester.ensureVisible(find.text('Gửi đánh giá'));
        await tester.tap(find.text('Gửi đánh giá'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn chia sẻ thêm một chút nhé 💙'), findsOneWidget);
        expect(
          await repository.getReviewForContractDetail(
            ReviewFixtures.defaultDevice.detailId,
          ),
          isNull,
        );
        await tester.tap(find.text('Viết nhận xét'));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, isTrue);
        expect(find.byIcon(Icons.star_rounded), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'x');
        await tester.ensureVisible(find.text('Gửi đánh giá'));
        await tester.tap(find.text('Gửi đánh giá'));
        await tester.pumpAndSettle();
        expect(
          (await repository.getReviewForContractDetail(
            ReviewFixtures.defaultDevice.detailId,
          ))!.comment,
          'x',
        );
      },
    );
    testWidgets(
      'State 1 (Chưa nhập): Renders empty form with disabled submit button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.defaultDevice,
              repository: MockReviewRepository(simulatedDelay: Duration.zero),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // App bar
        expect(find.text('Đánh giá thiết bị'), findsOneWidget);

        // Device Card
        expect(find.byType(ReviewDeviceCard), findsOneWidget);
        expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
        expect(find.text('Đã hoàn tất'), findsOneWidget);
        expect(find.text('HĐ: HD-2024-001 • Chi nhánh Quận 1'), findsOneWidget);

        // Star Rating Card
        expect(find.byType(ReviewStarRatingCard), findsOneWidget);
        expect(find.text('Trải nghiệm của bạn thế nào?'), findsOneWidget);
        expect(find.text('Chạm để đánh giá'), findsOneWidget);

        // Comment Card
        expect(find.byType(ReviewCommentCard), findsOneWidget);
        expect(find.text('0/500'), findsOneWidget);

        // Highlights Card
        expect(find.byType(ReviewHighlightsCard), findsOneWidget);
        expect(find.text('Điểm nổi bật của thiết bị'), findsOneWidget);
        expect(find.text('Chất lượng hình ảnh tốt'), findsOneWidget);
        expect(find.text('Phụ kiện đầy đủ'), findsNothing);

        // Images Card
        expect(find.byType(ReviewImagesCard), findsOneWidget);
        expect(find.text('0/4'), findsOneWidget);

        // Guideline Card
        expect(find.byType(ReviewGuidelineCard), findsOneWidget);
        expect(
          find.text(
            'Chia sẻ trải nghiệm thực tế, sử dụng ngôn ngữ phù hợp và tránh đăng thông tin cá nhân.',
          ),
          findsOneWidget,
        );

        // Primary Button disabled
        expect(
          find.widgetWithText(PrimaryButton, 'Gửi đánh giá'),
          findsOneWidget,
        );
        final elevatedButton = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.widgetWithText(PrimaryButton, 'Gửi đánh giá'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(elevatedButton.enabled, isFalse);

        // Ensure NO mock banners
        expect(find.text('BẢN MẪU UI'), findsNothing);
        expect(
          find.text('Flutter Engineering Specs & Data Contract'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'State 2 (Đang nhập / Đủ điều kiện): Tapping star enables submit button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.defaultDevice,
              repository: MockReviewRepository(simulatedDelay: Duration.zero),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 5th star
        final starFinder = find.byIcon(Icons.star_outline_rounded);
        expect(starFinder, findsNWidgets(5));
        await tester.tap(starFinder.at(4));
        await tester.pumpAndSettle();

        // Description changes to 'Rất hài lòng'
        expect(find.text('Rất hài lòng'), findsOneWidget);

        // Submit button is now enabled
        final elevatedButton = tester.widget<ElevatedButton>(
          find.descendant(
            of: find.widgetWithText(PrimaryButton, 'Gửi đánh giá'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(elevatedButton.enabled, isTrue);

        // Select a highlight chip
        await tester.ensureVisible(find.text('Thiết bị hoạt động ổn định'));
        await tester.tap(find.text('Thiết bị hoạt động ổn định'));
        await tester.pumpAndSettle();

        // Enter comment
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(
          find.byType(TextField),
          'Máy dùng rất mượt và êm.',
        );
        await tester.pumpAndSettle();
        expect(find.text('24/500'), findsOneWidget);
      },
    );

    testWidgets(
      'PopScope discard confirmation dialog triggers when form is modified',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.defaultDevice,
              repository: MockReviewRepository(simulatedDelay: Duration.zero),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Modify form
        await tester.tap(find.byIcon(Icons.star_outline_rounded).first);
        await tester.pumpAndSettle();

        // Tap back button
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();

        // Discard Dialog appears
        expect(find.text('Bỏ thay đổi?'), findsOneWidget);
        expect(
          find.text(
            'Bạn có thông tin đánh giá chưa gửi. Bạn có chắc chắn muốn rời khỏi màn hình này?',
          ),
          findsOneWidget,
        );

        // Tap "Tiếp tục chỉnh sửa" cancels discard
        await tester.tap(find.text('Tiếp tục chỉnh sửa'));
        await tester.pumpAndSettle();
        expect(find.text('Bỏ thay đổi?'), findsNothing);
        expect(find.text('Đánh giá thiết bị'), findsOneWidget);
      },
    );

    testWidgets(
      'State 5 (Chờ duyệt): Displays amber pending banner and read-only details',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.defaultDevice,
              initialReview: ReviewFixtures.pendingReview,
              initialViewMode: ReviewViewMode.hidden,
              repository: MockReviewRepository(simulatedDelay: Duration.zero),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pending Banner
        expect(find.byType(ReviewPendingCard), findsOneWidget);
        expect(find.text('Đánh giá đã bị ẩn'), findsOneWidget);
        expect(
          find.text('Nội dung không liên quan đến thiết bị.'),
          findsOneWidget,
        );

        // Read-only comment
        expect(
          find.textContaining(
            'Máy lấy nét nhanh, chống rung tốt khi quay cầm tay',
          ),
          findsOneWidget,
        );

        // Back CTA button
        expect(find.widgetWithText(OutlinedButton, 'Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'State 6 (Đã duyệt): Displays green approved banner, avatar, and verified badge',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReviewPage(
              device: ReviewFixtures.approvedDevice,
              initialReview: ReviewFixtures.approvedReview,
              initialViewMode: ReviewViewMode.published,
              repository: MockReviewRepository(simulatedDelay: Duration.zero),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Approved Banner
        expect(find.byType(ReviewApprovedCard), findsOneWidget);
        expect(find.text('Đánh giá công khai'), findsOneWidget);

        // Reviewer name & verified renter badge
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        expect(find.text('Đã thuê'), findsOneWidget);

        // Full comment
        expect(
          find.textContaining('Thiết bị ở tình trạng rất mới, sensor sạch sẽ'),
          findsOneWidget,
        );

        // Return to contract CTA
        expect(
          find.widgetWithText(PrimaryButton, 'Quay lại hợp đồng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Edge Case: Null device shows invalid data fallback with back button',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ReviewPage(device: null)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Không tìm thấy thông tin thiết bị cần đánh giá.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(OutlinedButton, 'Quay lại'), findsOneWidget);
      },
    );

    testWidgets(
      'ReviewPreviewPage renders scenario switcher and switches fixtures cleanly',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ReviewPreviewPage()));
        await tester.pumpAndSettle();

        expect(find.text('Preview Đánh giá thiết bị'), findsOneWidget);
        expect(find.text('Debug UI & Fixture Inspector'), findsOneWidget);

        // Default scenario is State 1 (Chưa nhập)
        expect(find.text('1. Chưa nhập (Trống)'), findsOneWidget);
        expect(find.text('Sony Alpha A7 IV'), findsOneWidget);

        // Switch to Approved scenario
        await tester.ensureVisible(find.text('6. Đã gửi (Công khai)'));
        await tester.tap(find.text('6. Đã gửi (Công khai)'));
        await tester.pumpAndSettle();

        expect(find.text('Canon EOS R6 Mark II'), findsOneWidget);
        expect(find.text('Đánh giá công khai'), findsOneWidget);
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
      },
    );
  });
}
