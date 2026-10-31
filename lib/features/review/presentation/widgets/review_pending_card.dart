import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_image_viewer_dialog.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/review_detail_model.dart';
import 'review_star_rating_card.dart';

class ReviewPendingCard extends StatelessWidget {
  final ReviewDetailModel review;

  const ReviewPendingCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rejected = ['AN', 'TU_CHOI'].contains(review.moderationStatus);
    final unknown = !rejected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pending Status Banner
        Container(
          decoration: BoxDecoration(
            color: rejected ? colors.errorContainer : const Color(0xFFFFFBE6),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius * 1.5),
            border: Border.all(
              color: rejected ? colors.error : const Color(0xFFFFE58F),
            ),
          ),
          padding: const EdgeInsets.all(AppSizes.pageMargin),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                rejected
                    ? Icons.error_outline
                    : Icons.access_time_filled_rounded,
                color: rejected ? colors.error : const Color(0xFFD46B08),
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      rejected
                          ? 'Đánh giá đã bị ẩn'
                          : unknown
                          ? 'Chưa xác định trạng thái hiển thị'
                          : 'Chưa xác định trạng thái hiển thị',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color:
                          rejected
                              ? colors.onErrorContainer
                              : const Color(0xFF873800),
                    ),
                    SizedBox(height: 4),
                    AppText(
                      rejected
                          ? (review.moderationNote ??
                              'Đánh giá không được công khai. Hiện chưa hỗ trợ sửa hoặc gửi lại.')
                          : unknown
                          ? 'Đánh giá đã lưu. Hãy tải lại để kiểm tra trạng thái.'
                          : 'Đánh giá đã lưu. Hãy tải lại để kiểm tra trạng thái.',
                      fontSize: 13,
                      color:
                          rejected
                              ? colors.onErrorContainer
                              : const Color(0xFFAD4E00),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacingM),
        // Read-only Review Summary Card
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius * 1.5),
            border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSizes.pageMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Nội dung đánh giá của bạn (Chỉ đọc)',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: AppSizes.spacingM),
              // Stars row
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final isFilled = review.rating >= index + 1;
                    return Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color:
                          isFilled
                              ? const Color(0xFFFAAD14)
                              : colors.outline.withValues(alpha: 0.5),
                    );
                  }),
                  const SizedBox(width: 8),
                  AppText(
                    ReviewStarRatingCard.getRatingLabel(review.rating),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
              if (review.highlights.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacingM),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      review.highlights.map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              AppText(
                                label,
                                fontSize: 12,
                                color: colors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ],
              if (review.comment.trim().isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacingM),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  child: AppText(
                    review.comment,
                    fontSize: 13.5,
                    style: const TextStyle(height: 1.45),
                  ),
                ),
              ],
              if (review.imageUrls.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacingM),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      review.imageUrls.map((url) {
                        return InkWell(
                          onTap:
                              () => AppImageViewerDialog.show(
                                context: context,
                                imageUrl: url,
                                title: 'Ảnh đính kèm',
                              ),
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadius,
                            ),
                            child: SizedBox(
                              width: 68,
                              height: 68,
                              child: AppImage(imageUrl: url, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
