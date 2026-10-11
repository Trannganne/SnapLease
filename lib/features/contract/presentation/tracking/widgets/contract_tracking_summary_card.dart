import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/widgets/app_text.dart';
import '../../../../../core/widgets/app_image.dart';
import '../../../services/contract_pdf_service.dart';
import '../models/contract_tracking_status.dart';
import 'contract_status_badge.dart';

class ContractTrackingSummaryCard extends StatelessWidget {
  final ContractModel contract;
  final ContractTrackingStatus status;

  const ContractTrackingSummaryCard({
    super.key,
    required this.contract,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final startDate = dateFormat.format(contract.pickupDate);
    final endDate = dateFormat.format(contract.returnDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: AppText(
                  'Mã HĐ: ${contract.contractId}',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ContractStatusBadge(status: status),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Center(
                  child: AppImage(
                    imageUrl: contract.deviceImageUrl ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    iconSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      contract.deviceName,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'Loại: ${contract.deviceModel}',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'Thời gian thuê: $startDate → $endDate',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    AppText(
                      '(${contract.rentalDays} ngày trọn gói)',
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Chi nhánh nhận:',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        contract.branchName,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Thanh toán:',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      const SizedBox(height: 2),
                      const AppText(
                        'Thanh toán tại quầy',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ],
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
