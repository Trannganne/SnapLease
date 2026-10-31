import 'package:equatable/equatable.dart';
import '../domain/models/review_detail_model.dart';
import '../domain/models/review_target_device.dart';
import '../domain/models/review_form.dart';

enum ReviewFormStatus { initial, editing, submitting, success, failure }

enum ReviewViewMode { inputForm, pendingApproval, published, hidden, unknown }

class ReviewState extends Equatable {
  final ReviewTargetDevice? targetDevice;
  final ReviewViewMode viewMode;
  final int rating;
  final String comment;
  final Set<String> selectedChips;
  final List<String> imagePaths;
  final ReviewFormStatus formStatus;
  final String? errorMessage;
  final bool hasUserModified;
  final ReviewDetailModel? submittedReview;
  final ReviewForm? form;
  final bool loading;
  final String? loadError;
  final bool uncertainCreate;
  final List<ReviewUpload> uploads;

  const ReviewState({
    this.targetDevice,
    this.viewMode = ReviewViewMode.inputForm,
    this.rating = 0,
    this.comment = '',
    this.selectedChips = const {},
    this.imagePaths = const [],
    this.formStatus = ReviewFormStatus.initial,
    this.errorMessage,
    this.hasUserModified = false,
    this.submittedReview,
    this.form,
    this.loading = false,
    this.loadError,
    this.uncertainCreate = false,
    this.uploads = const [],
  });

  bool get isSubmitting => formStatus == ReviewFormStatus.submitting;
  bool get isSuccess => formStatus == ReviewFormStatus.success;
  bool get isFailure => formStatus == ReviewFormStatus.failure;
  bool get canSubmit =>
      rating >= 1 &&
      rating <= 5 &&
      !isSubmitting &&
      !loading &&
      loadError == null &&
      !uncertainCreate &&
      submittedReview == null &&
      comment.length <= commentLimit &&
      (form?.canReview ?? true) &&
      (targetDevice?.isCompleted ?? false);

  int get commentLimit => form?.commentLimit ?? maxCommentLength;
  int get imageLimit => form?.imageLimit ?? maxImagesCount;

  int get commentLength => comment.length;
  static const int maxCommentLength = 500;
  static const int maxImagesCount = 4;

  bool get canAddImage =>
      imagePaths.length < imageLimit &&
      submittedReview == null &&
      !uncertainCreate;

  ReviewState copyWith({
    ReviewTargetDevice? targetDevice,
    ReviewViewMode? viewMode,
    int? rating,
    String? comment,
    Set<String>? selectedChips,
    List<String>? imagePaths,
    ReviewFormStatus? formStatus,
    String? errorMessage,
    bool? hasUserModified,
    ReviewDetailModel? submittedReview,
    ReviewForm? form,
    bool? loading,
    String? loadError,
    bool? uncertainCreate,
    List<ReviewUpload>? uploads,
  }) {
    return ReviewState(
      targetDevice: targetDevice ?? this.targetDevice,
      viewMode: viewMode ?? this.viewMode,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      selectedChips: selectedChips ?? this.selectedChips,
      imagePaths: imagePaths ?? this.imagePaths,
      formStatus: formStatus ?? this.formStatus,
      errorMessage: errorMessage,
      hasUserModified: hasUserModified ?? this.hasUserModified,
      submittedReview: submittedReview ?? this.submittedReview,
      form: form ?? this.form,
      loading: loading ?? this.loading,
      loadError: loadError,
      uncertainCreate: uncertainCreate ?? this.uncertainCreate,
      uploads: uploads ?? this.uploads,
    );
  }

  @override
  List<Object?> get props => [
    targetDevice,
    viewMode,
    rating,
    comment,
    selectedChips,
    imagePaths,
    formStatus,
    errorMessage,
    hasUserModified,
    submittedReview,
    form,
    loading,
    loadError,
    uncertainCreate,
    uploads,
  ];
}
