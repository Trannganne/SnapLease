import 'review_highlight_chip.dart';
import 'review_target_device.dart';

class ReviewForm {
  final ReviewTargetDevice device;
  final bool canReview;
  final String? reason;
  final String? existingReviewId;
  final int commentLimit;
  final int imageLimit;
  final List<ReviewHighlightChip> highlights;
  const ReviewForm({
    required this.device,
    required this.canReview,
    this.reason,
    this.existingReviewId,
    required this.commentLimit,
    required this.imageLimit,
    required this.highlights,
  });
}

enum ReviewUploadStatus { pending, uploaded, uncertain }

class ReviewUpload {
  final String path;
  final ReviewUploadStatus status;
  final String? serverId;
  final String? url;
  const ReviewUpload(
    this.path, {
    this.status = ReviewUploadStatus.pending,
    this.serverId,
    this.url,
  });
}

class ReviewFailure implements Exception {
  final String message;
  final int? status;
  final bool uncertain;
  const ReviewFailure(this.message, {this.status, this.uncertain = false});
  @override
  String toString() => message;
}
