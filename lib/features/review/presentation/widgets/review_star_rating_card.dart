import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';

class ReviewStarRatingCard extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final bool enabled;

  const ReviewStarRatingCard({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.enabled = true,
  });

  static String getRatingLabel(int star) {
    switch (star) {
      case 1:
        return 'Rất không hài lòng';
      case 2:
        return 'Không hài lòng';
      case 3:
        return 'Bình thường';
      case 4:
        return 'Hài lòng';
      case 5:
        return 'Rất hài lòng';
      default:
        return 'Chạm để đánh giá';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pageMargin,
        vertical: AppSizes.spacingM,
      ),
      child: Column(
        children: [
          const AppText(
            'Trải nghiệm của bạn thế nào?',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          AppText(
            'Hãy chia sẻ cảm nhận về thiết bị trong quá trình sử dụng',
            fontSize: 13,
            color: colors.onSurfaceVariant,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.spacingM),
          // 5 Stars row with touch-friendly targets
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isFilled = rating >= starNumber;
              return Semantics(
                button: true,
                label: '$starNumber sao, ${getRatingLabel(starNumber)}',
                selected: rating == starNumber,
                child: InkWell(
                  onTap: enabled ? () => onRatingChanged(starNumber) : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color:
                          isFilled
                              ? const Color(0xFFFAAD14)
                              : colors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSizes.spacingS),
          // Description text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: AppText(
              getRatingLabel(rating),
              key: ValueKey('rating_label_$rating'),
              fontSize: 14,
              fontWeight: rating > 0 ? FontWeight.w600 : FontWeight.normal,
              color:
                  rating > 0
                      ? (rating >= 4
                          ? const Color(0xFF389E0D)
                          : (rating == 3
                              ? const Color(0xFFD46B08)
                              : const Color(0xFFCF1322)))
                      : colors.onSurfaceVariant.withValues(alpha: 0.7),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
