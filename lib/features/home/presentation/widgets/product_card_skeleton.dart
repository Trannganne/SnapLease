import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/snap_skeleton.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        child: SizedBox(
          width: double.infinity,
          child: SkeletonBox(height: double.infinity, radius: 12),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 14),
            SizedBox(height: 4),
            FractionallySizedBox(
              widthFactor: .65,
              child: SkeletonBox(height: 12),
            ),
            SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: .7,
              child: SkeletonBox(height: 16),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 32, radius: 6)),
                SizedBox(width: 8),
                SkeletonBox(width: 32, height: 32, radius: 6),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// Matches the two-column, .7 aspect ratio used by Home and Explore.
class ProductLoadingGrid extends StatelessWidget {
  final bool embedded;
  const ProductLoadingGrid({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) => SnapSkeleton(
    label: 'Đang tải thiết bị',
    child: GridView.builder(
      padding:
          embedded
              ? EdgeInsets.zero
              : const EdgeInsets.all(AppSizes.pageMargin),
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, index) => const ProductCardSkeleton(),
    ),
  );
}
