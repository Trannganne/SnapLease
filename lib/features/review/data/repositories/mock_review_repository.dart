import '../../domain/models/review_detail_model.dart';
import '../../domain/models/review_submission_data.dart';
import 'review_repository.dart';
import '../../domain/models/review_form.dart';

class MockReviewRepository implements ReviewRepository {
  final Map<String, ReviewDetailModel> _storage = {};
  bool shouldFailSubmission = false;
  String? failureErrorMessage;
  Duration simulatedDelay;

  MockReviewRepository({
    Map<String, ReviewDetailModel>? initialReviews,
    this.shouldFailSubmission = false,
    this.failureErrorMessage,
    this.simulatedDelay = const Duration(milliseconds: 400),
  }) {
    if (initialReviews != null) {
      _storage.addAll(initialReviews);
    }
  }

  @override
  Future<ReviewDetailModel?> getReviewForContractDetail(String detailId) async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    return _storage[detailId];
  }

  @override
  Future<ReviewDetailModel> submitReview(
    ReviewSubmissionData submission,
  ) async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
    if (shouldFailSubmission) {
      throw Exception(
        failureErrorMessage ??
            'Lỗi kết nối khi gửi đánh giá. Vui lòng thử lại.',
      );
    }
    if (_storage.containsKey(submission.detailId)) {
      throw Exception('Chi tiết thiết bị này đã được đánh giá trước đó.');
    }

    _storage[submission.detailId] = ReviewDetailModel(
      reviewId: 'REV_${DateTime.now().millisecondsSinceEpoch}',
      detailId: submission.detailId,
      rating: submission.rating,
      comment: submission.comment,
      highlights: submission.highlights,
      imageUrls: submission.imagePaths,
      reviewerName: 'Khách thuê SNAPLEASE',
      reviewedAt: DateTime.now(),
      isVerifiedRenter: true,
      isApproved: false,
      isPublic: true,
      moderationStatus: 'CONG_KHAI',
    );
    return _storage[submission.detailId]!;
  }

  @override
  Future<ReviewForm> getForm(String detailId) async =>
      throw UnsupportedError('Preview uses its explicit fixture device.');

  @override
  Future<({String id, String url})> uploadImage(
    String reviewId,
    String path,
  ) async => (id: path, url: path);

  void seedReview(ReviewDetailModel review) {
    _storage[review.detailId] = review;
  }

  void clear() {
    _storage.clear();
  }
}
