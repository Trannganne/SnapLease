import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_notice_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';
import '../../../core/storage/token_storage.dart';
import 'package:go_router/go_router.dart';
import '../bloc/review_cubit.dart';
import '../bloc/review_state.dart';
import '../data/repositories/dio_review_repository.dart';
import '../domain/models/review_form.dart';
import '../data/repositories/review_repository.dart';
import '../domain/models/review_detail_model.dart';
import '../domain/models/review_target_device.dart';
import 'widgets/review_approved_card.dart';
import 'widgets/review_comment_card.dart';
import 'widgets/review_device_card.dart';
import 'widgets/review_guideline_card.dart';
import 'widgets/review_highlights_card.dart';
import 'widgets/review_images_card.dart';
import 'widgets/review_pending_card.dart';
import 'widgets/review_star_rating_card.dart';

class ReviewPage extends StatelessWidget {
  final ReviewTargetDevice? device;
  final String? detailId;
  final ReviewDetailModel? initialReview;
  final ReviewViewMode initialViewMode;
  final ReviewRepository? repository;
  final bool isPreview;

  const ReviewPage({
    super.key,
    this.device,
    this.detailId,
    this.initialReview,
    this.initialViewMode = ReviewViewMode.inputForm,
    this.repository,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    if (device == null && (detailId == null || detailId!.isEmpty)) {
      return Scaffold(
        appBar: AppBar(
          title: const AppText(
            'Đánh giá thiết bị',
            fontWeight: FontWeight.bold,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.pageMargin * 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                const AppText(
                  'Không tìm thấy thông tin thiết bị cần đánh giá.',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                AppText(
                  'Vui lòng truy cập từ danh sách thiết bị của hợp đồng đã hoàn tất hoặc trang Preview.',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final remote = detailId != null || repository == null && !isPreview;
    final id = detailId ?? device!.detailId;
    return BlocProvider<ReviewCubit>(
      key: ValueKey('$id:${identityHashCode(repository)}'),
      create: (context) {
        final cubit = ReviewCubit(
          repository: repository ?? DioReviewRepository(),
          isRemote: remote,
          sessionChanges: remote ? TokenStorage.changes : null,
          initialDevice: remote ? null : device,
          initialReview: remote ? null : initialReview,
          initialViewMode: initialViewMode,
        );
        if (remote) cubit.load(id);
        return cubit;
      },
      child: _ReviewPageContent(isPreview: isPreview),
    );
  }
}

class _ReviewPageContent extends StatefulWidget {
  final bool isPreview;

  const _ReviewPageContent({required this.isPreview});

  @override
  State<_ReviewPageContent> createState() => _ReviewPageContentState();
}

class _ReviewPageContentState extends State<_ReviewPageContent> {
  late final TextEditingController _commentController;
  final _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ReviewCubit>();
    _commentController = TextEditingController(text: cubit.state.comment);
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<bool> _handlePop(BuildContext context) async {
    final cubit = context.read<ReviewCubit>();
    final state = cubit.state;

    if (state.isSubmitting) return false;

    // Only prompt confirmation if user modified the form in input mode
    if (state.viewMode == ReviewViewMode.inputForm && state.hasUserModified) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const AppText('Bỏ thay đổi?', fontWeight: FontWeight.bold),
              content: const AppText(
                'Bạn có thông tin đánh giá chưa gửi. Bạn có chắc chắn muốn rời khỏi màn hình này?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const AppText('Tiếp tục chỉnh sửa'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const AppText('Bỏ thay đổi', color: Colors.red),
                ),
              ],
            ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  Future<void> _handleSubmit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final cubit = context.read<ReviewCubit>();

    if (cubit.state.rating <= 2 && cubit.state.comment.trim().isEmpty) {
      await showAppNoticeDialog(
        context,
        title: 'Bạn chia sẻ thêm một chút nhé 💙',
        message:
            'Điều gì khiến bạn chưa hài lòng? Ý kiến của bạn sẽ giúp cửa hàng cải thiện.',
        action: 'Viết nhận xét',
      );
      if (mounted) _commentFocus.requestFocus();
      return;
    }

    if (widget.isPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đang xem thử giao diện — chưa gửi đánh giá lên hệ thống.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    cubit.submit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocConsumer<ReviewCubit, ReviewState>(
      listenWhen:
          (previous, current) =>
              previous.formStatus != current.formStatus ||
              previous.errorMessage != current.errorMessage ||
              previous.loading != current.loading ||
              previous.loadError != current.loadError,
      listener: (context, state) {
        if (state.loading || state.targetDevice == null) {
          _commentController.clear();
        }
        if (state.formStatus == ReviewFormStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: colors.error,
            ),
          );
        } else if (state.formStatus == ReviewFormStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi đánh giá'),
              backgroundColor: Color(0xFF389E0D),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ReviewCubit>();
        if (state.loading || state.targetDevice == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Đánh giá thiết bị')),
            body: Center(
              child:
                  state.loading
                      ? const SnapLoadingView(
                        message: 'Đang tải thông tin đánh giá',
                        size: RetroCameraLoader.large,
                      )
                      : Padding(
                        padding: const EdgeInsets.all(AppSizes.pageMargin),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              state.loadError ??
                                  'Không tìm thấy thông tin thiết bị cần đánh giá.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: cubit.retryLoad,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
            ),
          );
        }
        final device = state.targetDevice!;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final canLeave = await _handlePop(context);
            if (canLeave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: SnapLoadingOverlay(
            loading: state.isSubmitting,
            message: 'Đang xử lý đánh giá của bạn',
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: colors.surface,
                elevation: 0,
                leading: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final canLeave = await _handlePop(context);
                    if (canLeave && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: const AppText(
                  'Đánh giá thiết bị',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSizes.pageMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Target Device Summary Card
                      ReviewDeviceCard(device: device),
                      if (state.form?.canReview == false &&
                          state.submittedReview == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppText(
                            state.form?.reason ??
                                'Hiện chưa được phép đánh giá.',
                          ),
                        ),
                      const SizedBox(height: AppSizes.spacingM),

                      // Content according to display mode
                      if (state.viewMode == ReviewViewMode.inputForm) ...[
                        // Star Rating Card
                        ReviewStarRatingCard(
                          rating: state.rating,
                          onRatingChanged: cubit.setRating,
                          enabled:
                              !state.isSubmitting &&
                              !state.uncertainCreate &&
                              (state.form?.canReview ?? true),
                        ),
                        const SizedBox(height: AppSizes.spacingM),

                        // Comment Textarea Card
                        ReviewCommentCard(
                          focusNode: _commentFocus,
                          controller: _commentController,
                          commentLength: state.commentLength,
                          maxLength: state.commentLimit,
                          onChanged: cubit.updateComment,
                          enabled:
                              !state.isSubmitting &&
                              !state.uncertainCreate &&
                              (state.form?.canReview ?? true),
                        ),
                        const SizedBox(height: AppSizes.spacingM),

                        // Highlights Chips Card
                        ReviewHighlightsCard(
                          selectedChips: state.selectedChips,
                          options: state.form?.highlights,
                          onChipToggled: cubit.toggleHighlightChip,
                          enabled:
                              !state.isSubmitting &&
                              !state.uncertainCreate &&
                              (state.form?.canReview ?? true),
                        ),
                        const SizedBox(height: AppSizes.spacingM),

                        // Images Picker & Preview Card
                        ReviewImagesCard(
                          images: state.imagePaths,
                          maxImages: state.imageLimit,
                          onImageAdded: cubit.addImage,
                          onImageRemoved: cubit.removeImageAt,
                          enabled:
                              !state.isSubmitting &&
                              !state.uncertainCreate &&
                              (state.form?.canReview ?? true),
                        ),
                        const SizedBox(height: AppSizes.spacingM),

                        // Guideline info card
                        const ReviewGuidelineCard(),
                      ] else if ((state.viewMode ==
                                  ReviewViewMode.pendingApproval ||
                              state.viewMode == ReviewViewMode.hidden ||
                              state.viewMode == ReviewViewMode.unknown) &&
                          state.submittedReview != null) ...[
                        ReviewPendingCard(review: state.submittedReview!),
                      ] else if (state.viewMode == ReviewViewMode.published &&
                          state.submittedReview != null) ...[
                        ReviewApprovedCard(review: state.submittedReview!),
                      ],

                      if (state.uncertainCreate) ...[
                        const AppText(
                          'Chưa xác định kết quả gửi. Cần đối soát trước khi gửi lại.',
                        ),
                        OutlinedButton(
                          onPressed:
                              state.isSubmitting
                                  ? null
                                  : cubit.reconcileCreation,
                          child: const Text('Đối soát đánh giá'),
                        ),
                      ],
                      if (state.uploads.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (var i = 0; i < state.uploads.length; i++)
                          AppText(
                            'Ảnh ${i + 1}: ${switch (state.uploads[i].status) {
                              ReviewUploadStatus.pending => 'Chưa gửi',
                              ReviewUploadStatus.uploaded => 'Đã tải lên',
                              ReviewUploadStatus.uncertain => 'Chưa xác định kết quả',
                            }}',
                          ),
                        if (state.uploads.any((x) => x.url != null))
                          ReviewImagesCard(
                            images:
                                state.uploads
                                    .where((x) => x.url != null)
                                    .map((x) => x.url!)
                                    .toList(),
                            onImageAdded: (_) {},
                            onImageRemoved: (_) {},
                            enabled: false,
                          ),
                        OutlinedButton(
                          onPressed:
                              state.isSubmitting
                                  ? null
                                  : () => cubit.reconcileImages(),
                          child: const Text('Đối soát ảnh'),
                        ),
                        if (!state.uploads.any(
                              (x) => x.status == ReviewUploadStatus.uncertain,
                            ) &&
                            state.uploads.any(
                              (x) => x.status == ReviewUploadStatus.pending,
                            ))
                          OutlinedButton(
                            onPressed:
                                state.isSubmitting
                                    ? null
                                    : () => cubit.reconcileImages(
                                      retryPending: true,
                                    ),
                            child: const Text('Gửi ảnh chưa gửi'),
                          ),
                      ],
                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppText(
                            state.errorMessage!,
                            color: colors.error,
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: Container(
                margin: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: colors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pageMargin,
                      vertical: 12,
                    ),
                    child: _buildBottomAction(context, state),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _leave(BuildContext context) {
    if (GoRouter.maybeOf(context) != null && context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (GoRouter.maybeOf(context) != null) {
      context.go('/?tab=contracts');
    }
  }

  Widget _buildBottomAction(BuildContext context, ReviewState state) {
    if (state.viewMode == ReviewViewMode.inputForm) {
      return PrimaryButton(
        text: 'Gửi đánh giá',
        isLoading: state.isSubmitting,
        showLoadingAnimation: false,
        onPressed: state.canSubmit ? () => _handleSubmit(context) : null,
      );
    } else if (state.viewMode == ReviewViewMode.hidden ||
        state.viewMode == ReviewViewMode.pendingApproval) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
        ),
        onPressed: state.isSubmitting ? null : () => _leave(context),
        child: const Text('Quay lại'),
      );
    } else {
      return PrimaryButton(
        text: 'Quay lại hợp đồng',
        onPressed: state.isSubmitting ? null : () => _leave(context),
      );
    }
  }
}
