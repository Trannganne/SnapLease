import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';
import '../models/contract_tracking_status.dart';
import '../models/contract_tracking_view_data.dart';

class CurrentContractStatusCard extends StatelessWidget {
  final ContractTrackingViewData viewData;

  const CurrentContractStatusCard({super.key, required this.viewData});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color titleColor;

    switch (viewData.status) {
      case ContractTrackingStatus.awaitingHandover:
      case ContractTrackingStatus.awaitingReturn:
        backgroundColor = Colors.orange.withValues(alpha: 0.05);
        titleColor = Colors.orange.shade800;
        break;
      case ContractTrackingStatus.renting:
        backgroundColor = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.05);
        titleColor = Theme.of(context).colorScheme.primary;
        break;
      case ContractTrackingStatus.completed:
        backgroundColor = Colors.green.withValues(alpha: 0.05);
        titleColor = Colors.green.shade800;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: titleColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  viewData.currentStatusTitle,
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (viewData.status == ContractTrackingStatus.awaitingHandover) ...[
            const SizedBox(height: 8),
            AppText(
              'Cập nhật lúc: 08:45 • Hôm nay',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ],
          const SizedBox(height: 12),
          AppText(viewData.currentStatusDescription, fontSize: 14),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: titleColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available, color: titleColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    viewData.highlightText,
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
