import '../../domain/models/review_detail_model.dart';
import '../../domain/models/review_submission_data.dart';
import '../../domain/models/review_form.dart';

abstract class ReviewRepository {
  Future<ReviewDetailModel?> getReviewForContractDetail(String detailId);
  Future<ReviewDetailModel> submitReview(ReviewSubmissionData submission);
  Future<ReviewForm> getForm(String detailId);
  Future<({String id, String url})> uploadImage(String reviewId, String path);
}
