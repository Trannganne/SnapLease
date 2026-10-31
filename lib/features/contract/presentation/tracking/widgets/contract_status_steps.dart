import 'package:flutter/material.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/widgets/app_text.dart';
import '../models/contract_tracking_status.dart';

/// Read-only: selected progress comes exclusively from the contract status.
class ContractStatusSteps extends StatelessWidget {
  final ContractTrackingStatus status;
  final bool includeOtherStatus;
  const ContractStatusSteps({
    super.key,
    required this.status,
    this.includeOtherStatus = false,
  });
  @override
  Widget build(BuildContext context) {
    const primaryStages = [
      ContractTrackingStatus.awaitingHandover,
      ContractTrackingStatus.renting,
      ContractTrackingStatus.awaitingReturn,
      ContractTrackingStatus.completed,
    ];
    final isCancelled = status == ContractTrackingStatus.cancelled;
    final stages =
        isCancelled
            ? [ContractTrackingStatus.cancelled]
            : [
              if (includeOtherStatus && !primaryStages.contains(status)) status,
              ...primaryStages,
            ];
    final colors = Theme.of(context).colorScheme;
    final current = stages.indexOf(status);
    return Wrap(
      spacing: 4,
      runSpacing: AppSizes.spacingS,
      children: [
        for (var i = 0; i < stages.length; i++)
          Semantics(
            selected: i == current,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color:
                    i == current
                        ? (isCancelled ? colors.errorContainer : colors.primary)
                        : colors.primary.withValues(alpha: .065),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i == current) ...[
                    Icon(
                      isCancelled ? Icons.cancel_outlined : Icons.circle,
                      size: isCancelled ? 14 : 5,
                      color:
                          isCancelled
                              ? colors.onErrorContainer
                              : colors.onPrimary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: AppText(
                      stages[i].label,
                      fontSize: 11,
                      fontWeight:
                          i == current ? FontWeight.w600 : FontWeight.normal,
                      color:
                          i == current
                              ? (isCancelled
                                  ? colors.onErrorContainer
                                  : colors.onPrimary)
                              : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
