import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';
import '../../../services/contract_pdf_service.dart';
import '../models/contract_tracking_status.dart';
import 'contract_status_badge.dart';
import 'package:intl/intl.dart';

class ContractTrackingSummaryCard extends StatelessWidget {
  final ContractModel contract;
  final ContractTrackingStatus status;
  final bool showRentalDetails;
  final VoidCallback? onCopy;
  final VoidCallback? onTrack;

  const ContractTrackingSummaryCard({
    super.key,
    required this.contract,
    required this.status,
    this.showRentalDetails = false,
    this.onCopy,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
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
          if (showRentalDetails) ...[
            _rentalHeader(context),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (contract.bookedDevices.isEmpty)
                          const AppText(
                            'Chưa có thông tin dòng máy đặt thuê',
                            fontSize: 13,
                          )
                        else
                          for (final model in contract.bookedDevices)
                            AppText(
                              '${model.name} • ${model.quantity} thiết bị',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _summaryField(
                  context,
                  Icons.date_range_outlined,
                  'Lịch thuê',
                  '${DateFormat('dd/MM/yyyy').format(contract.pickupDate)} → ${DateFormat('dd/MM/yyyy').format(contract.effectiveReturnDate)}',
                ),
                _summaryField(
                  context,
                  Icons.storefront_outlined,
                  'Chi nhánh',
                  contract.branchName,
                ),
              ],
            ),
            if (contract.proposedReturnDate != null) ...[
              const SizedBox(height: 8),
              AppText('Gia hạn chờ duyệt • Ngày đề nghị: ${DateFormat('dd/MM/yyyy').format(contract.proposedReturnDate!)}',
                fontSize: 13, color: Theme.of(context).colorScheme.primary),
            ],
            if (onTrack != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('contract-open-tracking'),
                  onPressed: onTrack,
                  icon: const Icon(Icons.timeline_outlined, size: 18),
                  label: const Text(
                    'Theo dõi trạng thái',
                    textAlign: TextAlign.center,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ] else
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
        ],
      ),
    );
  }

  Widget _rentalHeader(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final id = Row(
        children: [
          Expanded(
            child: SelectableText(
              contract.contractId,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Sao chép mã hợp đồng',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 18),
            ),
        ],
      );
      final badge = ContractStatusBadge(status: status);
      if (constraints.maxWidth < 320 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [id, const SizedBox(height: 8), badge],
        );
      }
      return Row(
        children: [Expanded(child: id), const SizedBox(width: 8), badge],
      );
    },
  );

  Widget _summaryField(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              label,
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            AppText(
              value.isEmpty ? 'Chưa có thông tin' : value,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    ],
  );
}
