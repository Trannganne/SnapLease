import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../models/notification_detail_view_data.dart';

class NotificationDetailSummaryCard extends StatelessWidget {
  final NotificationDetailViewData viewData;

  const NotificationDetailSummaryCard({
    super.key,
    required this.viewData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        // Event Icon in rounded container with soft tinted background
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: viewData.headerIconBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: viewData.headerIconColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(
            viewData.headerIcon,
            color: viewData.headerIconColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 10),

        // Event Badge (e.g. 'Hoàn thành')
        if (viewData.subtitleBadgeText != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            decoration: BoxDecoration(
              color: viewData.subtitleBadgeBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: viewData.subtitleBadgeColor ?? Colors.transparent,
                width: 0.8,
              ),
            ),
            child: AppText(
              viewData.subtitleBadgeText!,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: viewData.subtitleBadgeColor ?? colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Prominent Title centered
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppText(
            viewData.title,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),

        // Sent time below
        AppText(
          viewData.timeFormatted,
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
