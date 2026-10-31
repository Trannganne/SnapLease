import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';

class ReviewCommentCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int commentLength;
  final int maxLength;
  final bool enabled;
  final FocusNode? focusNode;

  const ReviewCommentCard({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.commentLength,
    this.maxLength = 500,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentLength = commentLength;

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
          const AppText(
            'Nhận xét của bạn',
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 4),
          AppText(
            'Chia sẻ cụ thể giúp người thuê sau có thêm thông tin tham khảo',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSizes.spacingM),
          // Textarea Container
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              border: Border.all(color: colors.outline.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  focusNode: focusNode,
                  controller: controller,
                  onTapOutside:
                      (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: onChanged,
                  enabled: enabled,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: maxLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null, // Hide default counter to customize below
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontFamily: 'Roboto',
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Chia sẻ về chất lượng thiết bị và trải nghiệm sử dụng…',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.bottomRight,
                  child: AppText(
                    '$currentLength/$maxLength',
                    fontSize: 12,
                    color:
                        currentLength >= maxLength
                            ? Colors.red
                            : colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
