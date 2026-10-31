import 'package:flutter/material.dart';
import '../../../../../core/widgets/snap_skeleton.dart';

class ContractCardSkeleton extends StatelessWidget {
  const ContractCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: const Column(
      children: [
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 16)),
            SizedBox(width: 24),
            SkeletonBox(width: 72, height: 24, radius: 12),
          ],
        ),
        SizedBox(height: 16),
        Divider(height: 1),
        SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 80, height: 80),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 18),
                  SizedBox(height: 8),
                  SkeletonBox(height: 13),
                  SizedBox(height: 12),
                  SkeletonBox(height: 13),
                  SizedBox(height: 8),
                  SkeletonBox(height: 13),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Divider(height: 1),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SkeletonBox(height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(height: 18),
                ],
              ),
            ),
            SizedBox(width: 24),
            SkeletonBox(width: 96, height: 36),
          ],
        ),
      ],
    ),
  );
}
