import '../../domain/models/review_detail_model.dart';
import '../../domain/models/review_form.dart';
import '../../domain/models/review_submission_data.dart';
import '../review_api_dto.dart';
import '../review_remote_data_source.dart';
import 'review_repository.dart';

class DioReviewRepository implements ReviewRepository {
  final ReviewRemoteDataSource remote;
  DioReviewRepository({ReviewRemoteDataSource? remote})
    : remote = remote ?? ReviewRemoteDataSource();
  @override
  Future<ReviewForm> getForm(String detailId) async => ReviewApiDto.form(
    await remote.request(
      '/api/danh-gia/bieu-mau/${Uri.encodeComponent(detailId)}',
    ),
    detailId,
  );
  @override
  Future<ReviewDetailModel?> getReviewForContractDetail(String detailId) async {
    final rows = ReviewApiDto.rows(
      await remote.request('/api/danh-gia/cua-toi'),
    );
    final matches =
        rows.where((x) => x['maChiTietHopDong'] == detailId).toList();
    if (matches.length > 1) {
      throw const FormatException('API trả nhiều đánh giá cho một thiết bị.');
    }
    return matches.isEmpty ? null : ReviewApiDto.review(matches.single);
  }

  @override
  Future<ReviewDetailModel> submitReview(
    ReviewSubmissionData submission,
  ) async {
    final data = await remote.request(
      '/api/danh-gia',
      method: 'POST',
      data: submission.toApiJson(),
    );
    try {
      final review = ReviewApiDto.review(data);
      if (review.detailId != submission.detailId) {
        throw const FormatException('API trả sai đánh giá.');
      }
      return review;
    } catch (_) {
      throw const ReviewFailure(
        'Chưa xác định kết quả gửi. Cần tải lại để đối soát.',
        uncertain: true,
      );
    }
  }

  @override
  Future<({String id, String url})> uploadImage(
    String reviewId,
    String path,
  ) async {
    final data = await remote.upload(reviewId, path);
    try {
      final j = ReviewApiDto.object(data);
      return (
        id: ReviewApiDto.requiredString(j, 'maAnhDanhGia'),
        url: ReviewApiDto.requiredString(j, 'duongDanAnh'),
      );
    } catch (_) {
      throw const ReviewFailure(
        'Chưa xác định kết quả tải ảnh.',
        uncertain: true,
      );
    }
  }
}
