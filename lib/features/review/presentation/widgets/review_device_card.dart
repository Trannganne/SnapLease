import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/review_target_device.dart';

class ReviewDeviceCard extends StatelessWidget {
  final ReviewTargetDevice device;

  const ReviewDeviceCard({super.key, required this.device});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device image thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            child: SizedBox(
              width: 76,
              height: 76,
              child: AppImage(
                imageUrl: device.deviceImageUrl ?? '',
                fit: BoxFit.cover,
                iconSize: 32,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacingM),
          // Device info details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category/Brand & Status badge row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (device.categoryName != null &&
                        device.categoryName!.isNotEmpty)
                      Expanded(
                        child: AppText(
                          device.categoryName!.toUpperCase(),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else if (device.brandName != null &&
                        device.brandName!.isNotEmpty)
                      Expanded(
                        child: AppText(
                          device.brandName!.toUpperCase(),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                    _buildStatusBadge(context),
                  ],
                ),
                const SizedBox(height: 4),
                // Model Name
                AppText(
                  device.modelName,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Contract ID and Branch
                AppText(
                  'HĐ: ${device.contractId} • ${device.branchName}',
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Serial number (if present)
                if (device.serialNumber != null &&
                    device.serialNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  AppText(
                    'Serial: ${device.serialNumber}',
                    fontSize: 11,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isDone = device.isCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF6FFED) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? const Color(0xFFB7EB8F) : const Color(0xFFFFD591),
        ),
      ),
      child: AppText(
        isDone ? 'Đã hoàn tất' : 'Chưa hoàn tất',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: isDone ? const Color(0xFF389E0D) : const Color(0xFFD46B08),
      ),
    );
  }
}
