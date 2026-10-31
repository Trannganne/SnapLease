import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/review_highlight_chip.dart';

class ReviewHighlightsCard extends StatelessWidget {
  final Set<String> selectedChips;
  final ValueChanged<String> onChipToggled;
  final bool enabled;
  final List<ReviewHighlightChip>? options;

  const ReviewHighlightsCard({
    super.key,
    required this.selectedChips,
    required this.onChipToggled,
    this.enabled = true,
    this.options,
  });

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
      padding: const EdgeInsets.all(AppSizes.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const AppText(
                'Điểm nổi bật của thiết bị',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              AppText(
                '(Chọn nhiều mục)',
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingM),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                (options ?? ReviewHighlightChip.options).map((option) {
                  final isSelected = selectedChips.contains(
                    options == null ? option.label : option.id,
                  );
                  return InkWell(
                    onTap:
                        enabled
                            ? () => onChipToggled(
                              options == null ? option.label : option.id,
                            )
                            : null,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? colors.primary.withValues(alpha: 0.1)
                                : colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? colors.primary
                                  : colors.outline.withValues(alpha: 0.35),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          AppText(
                            option.label,
                            fontSize: 13,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color:
                                isSelected ? colors.primary : colors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}
