import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';
import '../models/contract_tracking_status.dart';

class ContractStatusBadge extends StatelessWidget {
  final ContractTrackingStatus status;

  const ContractStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case ContractTrackingStatus.awaitingHandover:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange.shade700;
        label = 'Chờ bàn giao';
        break;
      case ContractTrackingStatus.renting:
        backgroundColor = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1);
        textColor = Theme.of(context).colorScheme.primary;
        label = 'Đang thuê thiết bị';
        break;
      case ContractTrackingStatus.awaitingReturn:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange.shade700;
        label = 'Chờ hoàn trả';
        break;
      case ContractTrackingStatus.completed:
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade700;
        label = 'Hợp đồng hoàn tất';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AppText(
        label,
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
