import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/repositories/review_repository.dart';
import '../domain/models/review_detail_model.dart';
import '../domain/models/review_submission_data.dart';
import '../domain/models/review_target_device.dart';
import '../domain/models/review_form.dart';
import 'review_state.dart';

class ReviewCubit extends Cubit<ReviewState> {
  final ReviewRepository _repository;
  final bool isRemote;
  int _generation = 0;
  String? _detailId;
  StreamSubscription<void>? _sessionSubscription;

  ReviewCubit({
    required ReviewRepository repository,
    this.isRemote = false,
    Stream<void>? sessionChanges,
    ReviewTargetDevice? initialDevice,
    ReviewDetailModel? initialReview,
    ReviewViewMode initialViewMode = ReviewViewMode.inputForm,
  }) : _repository = repository,
       super(
         ReviewState(
           targetDevice: initialDevice,
           submittedReview: initialReview,
           viewMode: initialViewMode,
         ),
       ) {
    if (isRemote && sessionChanges != null) {
      _sessionSubscription = sessionChanges.listen((_) => invalidateSession());
    }
  }

  bool _active(int generation) => !isClosed && generation == _generation;
  bool get _editable =>
      !state.isSubmitting &&
      !state.uncertainCreate &&
      state.submittedReview == null &&
      !state.loading &&
      state.loadError == null;

  void invalidateSession() {
    ++_generation;
    if (!isClosed) {
      emit(
        const ReviewState(
          loadError: 'Phiên đăng nhập đã thay đổi. Hãy tải lại.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    ++_generation;
    _sessionSubscription?.cancel();
    return super.close();
  }

  ReviewViewMode _mode(ReviewDetailModel review) => switch (review
      .moderationStatus) {
    'CHO_DUYET' => ReviewViewMode.unknown,
    'CONG_KHAI' => ReviewViewMode.published,
    'DA_DUYET' => ReviewViewMode.published,
    'TU_CHOI' || 'AN' => ReviewViewMode.hidden,
    _ =>
      isRemote
          ? ReviewViewMode.unknown
          : review.isPublic
          ? ReviewViewMode.published
          : ReviewViewMode.pendingApproval,
  };

  Future<void> load(String detailId) async {
    _detailId = detailId;
    final generation = ++_generation;
    emit(const ReviewState(loading: true));
    try {
      final form = await _repository.getForm(detailId);
      if (!_active(generation)) return;
      ReviewDetailModel? review;
      if (form.existingReviewId != null) {
        review = await _repository.getReviewForContractDetail(detailId);
        if (review == null || review.reviewId != form.existingReviewId) {
          throw const ReviewFailure(
            'Không đối chiếu được đánh giá đã gửi. Hãy tải lại.',
          );
        }
      }
      if (!_active(generation)) return;
      emit(
        ReviewState(
          targetDevice: form.device,
          form: form,
          submittedReview: review,
          viewMode: review == null ? ReviewViewMode.inputForm : _mode(review),
        ),
      );
    } catch (e) {
      if (_active(generation)) {
        emit(ReviewState(loadError: e.toString()));
      }
    }
  }

  Future<void> retryLoad() async {
    if (_detailId != null && !state.isSubmitting) {
      await load(_detailId!);
    }
  }

  void loadDevice(
    ReviewTargetDevice device, {
    ReviewDetailModel? existingReview,
    ReviewViewMode viewMode = ReviewViewMode.inputForm,
  }) {
    ++_generation;
    emit(
      ReviewState(
        targetDevice: device,
        submittedReview: existingReview,
        viewMode: viewMode,
      ),
    );
  }

  void setRating(int rating) {
    if (!_editable || rating < 1 || rating > 5) return;
    emit(
      state.copyWith(
        rating: rating,
        hasUserModified: true,
        formStatus: ReviewFormStatus.editing,
      ),
    );
  }

  void updateComment(String text) {
    if (!_editable) return;
    final comment =
        text.length > state.commentLimit
            ? text.substring(0, state.commentLimit)
            : text;
    emit(
      state.copyWith(
        comment: comment,
        hasUserModified: true,
        formStatus: ReviewFormStatus.editing,
      ),
    );
  }

  void toggleHighlightChip(String code) {
    if (!_editable) return;
    if (isRemote &&
        !(state.form?.highlights.any((x) => x.id == code) ?? false)) {
      return;
    }
    final selected = Set<String>.of(state.selectedChips);
    if (!selected.remove(code)) {
      selected.add(code);
    }
    emit(
      state.copyWith(
        selectedChips: selected,
        hasUserModified: true,
        formStatus: ReviewFormStatus.editing,
      ),
    );
  }

  void addImage(String path) {
    if (!_editable || !state.canAddImage || state.imagePaths.contains(path)) {
      return;
    }
    emit(
      state.copyWith(
        imagePaths: [...state.imagePaths, path],
        hasUserModified: true,
        formStatus: ReviewFormStatus.editing,
      ),
    );
  }

  void removeImageAt(int index) {
    if (!_editable || index < 0 || index >= state.imagePaths.length) return;
    final paths = List<String>.of(state.imagePaths)..removeAt(index);
    emit(
      state.copyWith(
        imagePaths: paths,
        hasUserModified: true,
        formStatus: ReviewFormStatus.editing,
      ),
    );
  }

  void clearError() {
    emit(
      state.copyWith(
        formStatus:
            state.isFailure ? ReviewFormStatus.editing : state.formStatus,
      ),
    );
  }

  void setViewMode(ReviewViewMode mode, {ReviewDetailModel? review}) {
    emit(state.copyWith(viewMode: mode, submittedReview: review));
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    if (state.rating <= 2 && state.comment.trim().isEmpty) {
      emit(
        state.copyWith(
          formStatus: ReviewFormStatus.failure,
          errorMessage: 'Vui lòng viết nhận xét khi chọn 1 hoặc 2 sao.',
        ),
      );
      return;
    }
    final device = state.targetDevice!;
    final generation = _generation;
    emit(state.copyWith(formStatus: ReviewFormStatus.submitting));
    try {
      final review = await _repository.submitReview(
        ReviewSubmissionData(
          detailId: device.detailId,
          rating: state.rating,
          comment: state.comment,
          highlights: state.selectedChips.toList(),
          imagePaths: state.imagePaths,
        ),
      );
      if (!_active(generation)) return;
      emit(
        state.copyWith(
          submittedReview: review,
          viewMode: _mode(review),
          uploads:
              isRemote
                  ? state.imagePaths.map((p) => ReviewUpload(p)).toList()
                  : const [],
          hasUserModified: false,
        ),
      );
      if (isRemote) {
        await _uploadPending(generation);
      }
      if (_active(generation) && state.isSubmitting) {
        emit(state.copyWith(formStatus: ReviewFormStatus.success));
      }
    } catch (e) {
      if (!_active(generation)) return;
      if (isRemote && e is ReviewFailure && (e.uncertain || e.status == 409)) {
        emit(state.copyWith(uncertainCreate: true));
        await reconcileCreation();
      } else {
        emit(
          state.copyWith(
            formStatus: ReviewFormStatus.failure,
            errorMessage: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
      }
    }
  }

  Future<void> reconcileCreation() async {
    if (state.isSubmitting && !state.uncertainCreate) return;
    final id = state.targetDevice?.detailId;
    if (id == null) return;
    final generation = _generation;
    emit(
      state.copyWith(
        formStatus: ReviewFormStatus.submitting,
        uncertainCreate: true,
      ),
    );
    try {
      final form = await _repository.getForm(id);
      if (!_active(generation)) return;
      final review = await _repository.getReviewForContractDetail(id);
      if (!_active(generation)) return;
      if (review != null &&
          (form.existingReviewId == null ||
              form.existingReviewId == review.reviewId)) {
        // It may be another writer's review: never attach local photos automatically.
        emit(
          state.copyWith(
            form: form,
            submittedReview: review,
            viewMode: _mode(review),
            uncertainCreate: false,
            uploads:
                state.imagePaths.map((path) => ReviewUpload(path)).toList(),
            formStatus: ReviewFormStatus.success,
            hasUserModified: false,
            errorMessage:
                state.imagePaths.isEmpty
                    ? null
                    : 'Đã tìm thấy đánh giá. Ảnh đã chọn chưa được gửi; hãy kiểm tra ảnh trên máy chủ trước khi chủ động gửi phần còn lại.',
          ),
        );
      } else if (form.existingReviewId == null && form.canReview) {
        emit(
          state.copyWith(
            form: form,
            uncertainCreate: false,
            formStatus: ReviewFormStatus.failure,
            errorMessage:
                'Chưa thấy đánh giá trên máy chủ. Bạn có thể chủ động gửi lại; ứng dụng không tự gửi lại.',
          ),
        );
      } else if (form.existingReviewId == null && review == null) {
        emit(
          state.copyWith(
            form: form,
            uncertainCreate: false,
            formStatus: ReviewFormStatus.failure,
            errorMessage: form.reason ?? 'Hiện chưa được phép đánh giá.',
          ),
        );
      } else {
        throw const ReviewFailure('Dữ liệu đối soát không nhất quán.');
      }
    } catch (_) {
      if (_active(generation)) {
        emit(
          state.copyWith(
            uncertainCreate: true,
            formStatus: ReviewFormStatus.failure,
            errorMessage:
                'Chưa xác định kết quả gửi. Hãy đối soát trước khi gửi lại.',
          ),
        );
      }
    }
  }

  Future<void> _uploadPending(int generation) async {
    final review = state.submittedReview!;
    for (var i = 0; i < state.uploads.length; i++) {
      if (!_active(generation)) return;
      final upload = state.uploads[i];
      if (upload.status != ReviewUploadStatus.pending) continue;
      try {
        final response = await _repository.uploadImage(
          review.reviewId,
          upload.path,
        );
        if (!_active(generation)) return;
        final updated = List<ReviewUpload>.of(state.uploads);
        updated[i] = ReviewUpload(
          upload.path,
          status: ReviewUploadStatus.uploaded,
          serverId: response.id,
          url: response.url,
        );
        emit(state.copyWith(uploads: updated));
      } catch (e) {
        if (!_active(generation)) return;
        final unknown = e is! ReviewFailure || e.uncertain;
        final updated = List<ReviewUpload>.of(state.uploads);
        if (unknown) {
          updated[i] = ReviewUpload(
            upload.path,
            status: ReviewUploadStatus.uncertain,
          );
        }
        emit(
          state.copyWith(
            uploads: updated,
            formStatus: ReviewFormStatus.failure,
            errorMessage:
                unknown
                    ? 'Đánh giá đã lưu. Một ảnh chưa xác định kết quả; hãy đối soát, không tải lại ảnh đó.'
                    : 'Đánh giá đã lưu. Một số ảnh chưa gửi: $e',
          ),
        );
        return;
      }
    }
    if (!_active(generation)) return;
    try {
      final fresh = await _repository.getReviewForContractDetail(
        review.detailId,
      );
      if (!_active(generation)) return;
      if (fresh == null || fresh.reviewId != review.reviewId) {
        throw const ReviewFailure('Không đối chiếu được đánh giá.');
      }
      emit(state.copyWith(submittedReview: fresh, viewMode: _mode(fresh)));
    } catch (_) {
      if (_active(generation)) {
        emit(
          state.copyWith(
            formStatus: ReviewFormStatus.failure,
            errorMessage:
                'Đánh giá đã lưu. Chưa tải lại được ảnh từ máy chủ; hãy đối soát.',
          ),
        );
      }
    }
  }

  Future<void> reconcileImages({bool retryPending = false}) async {
    if (state.isSubmitting || state.submittedReview == null) return;
    final generation = _generation;
    final review = state.submittedReview!;
    emit(state.copyWith(formStatus: ReviewFormStatus.submitting));
    try {
      final fresh = await _repository.getReviewForContractDetail(
        review.detailId,
      );
      if (!_active(generation)) return;
      if (fresh == null || fresh.reviewId != review.reviewId) {
        throw const ReviewFailure('Không đối chiếu được đánh giá.');
      }
      final unknown = state.uploads.any(
        (x) => x.status == ReviewUploadStatus.uncertain,
      );
      emit(state.copyWith(submittedReview: fresh, viewMode: _mode(fresh)));
      if (unknown) {
        emit(
          state.copyWith(
            formStatus: ReviewFormStatus.failure,
            errorMessage:
                'Đã cập nhật ảnh máy chủ. API chưa có mã đối soát ảnh local; không thể xác định ảnh timeout đã nhận, không tải lại mù.',
          ),
        );
        return;
      }
      if (retryPending) {
        if (!fresh.isPublic) {
          emit(
            state.copyWith(
              formStatus: ReviewFormStatus.failure,
              errorMessage: 'Đánh giá không công khai nên không thể thêm ảnh.',
            ),
          );
          return;
        }
        await _uploadPending(generation);
      }
      if (_active(generation) && state.isSubmitting) {
        emit(state.copyWith(formStatus: ReviewFormStatus.success));
      }
    } catch (e) {
      if (_active(generation)) {
        emit(
          state.copyWith(
            formStatus: ReviewFormStatus.failure,
            errorMessage: 'Không đối soát được ảnh. Không tự gửi lại: $e',
          ),
        );
      }
    }
  }
}
