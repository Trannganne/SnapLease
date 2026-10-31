import 'package:flutter/material.dart';
import '../../../../core/widgets/snap_skeleton.dart';

/// Same icon, content and timestamp geometry as NotificationCard.
class NotificationItemSkeleton extends StatelessWidget {
  const NotificationItemSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 44, height: 44, radius: 22),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: .8,
                child: SkeletonBox(height: 14),
              ),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
              SizedBox(height: 6),
              FractionallySizedBox(
                widthFactor: .9,
                child: SkeletonBox(height: 12),
              ),
              SizedBox(height: 10),
              SkeletonBox(width: 80, height: 10),
            ],
          ),
        ),
      ],
    ),
  );
}
