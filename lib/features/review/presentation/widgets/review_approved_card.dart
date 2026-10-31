import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_image_viewer_dialog.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/review_detail_model.dart';
import 'review_star_rating_card.dart';

class ReviewApprovedCard extends StatelessWidget {
  final ReviewDetailModel review;

  const ReviewApprovedCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formattedDate = DateFormat('dd/MM/yyyy').format(review.reviewedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Approved Green Banner
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6FFED),
            borderRadius: BorderRadius.circular(AppSizes.borderRadius * 1.5),
            border: Border.all(color: const Color(0xFFB7EB8F)),
          ),
          padding: const EdgeInsets.all(AppSizes.pageMargin),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF52C41A),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Đánh giá công khai',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF135200),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      review.isPublic
                          ? 'Đánh giá của bạn đang hiển thị công khai trên trang sản phẩm.'
                          : 'Cảm ơn bạn đã đóng góp đánh giá cho cộng đồng người thuê thiết bị.',
                      fontSize: 13,
                      color: const Color(0xFF237804),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacingM),
        // Public/Approved Review Card
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
              // Header: User avatar, name, verified badge & date
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar(
                    displayName: review.reviewerName,
                    imageUrl: review.reviewerAvatar,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: AppText(
                                review.reviewerName,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (review.isVerifiedRenter) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F4FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF91CAFF),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 12,
                                      color: Color(0xFF0958D9),
                                    ),
                                    SizedBox(width: 3),
                                    AppText(
                                      'Đã thuê',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0958D9),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        AppText(
                          formattedDate,
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingM),
              // Stars and Rating label
              Row(
                children: [
                  ...List.generate(5, (index) {
                    final isFilled = review.rating >= index + 1;
                    return Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 22,
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
              // Highlights chips
              if (review.highlights.isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacingS),
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
                              color: colors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                size: 13,
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
              // Comment full text
              if (review.comment.trim().isNotEmpty) ...[
                const SizedBox(height: AppSizes.spacingM),
                AppText(
                  review.comment,
                  fontSize: 14,
                  style: const TextStyle(height: 1.5),
                ),
              ],
              // Attached images
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
                                title: 'Ảnh từ người dùng',
                              ),
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadius,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadius,
                            ),
                            child: SizedBox(
                              width: 72,
                              height: 72,
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
