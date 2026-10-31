import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../contract/services/contract_pdf_service.dart';
import '../models/notification_detail_view_data.dart';

class NotificationRelatedContractCard extends StatelessWidget {
  final ContractModel contract;
  final NotificationDetailViewData viewData;
  final Map<String, dynamic>? metadata;

  const NotificationRelatedContractCard({
    super.key,
    required this.contract,
    required this.viewData,
    this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final contractId = contract.contractId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Contract Info & ID Badge for completed, or ID and Status Badge for others
          if (viewData.variant == NotificationDetailVariant.completed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: AppText(
                          'Thông tin hợp đồng',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: AppText(
                    contractId.startsWith('#') ? contractId : '#$contractId',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'MÃ HỢP ĐỒNG',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                        style: const TextStyle(letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        contractId,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: viewData.contractStatusBgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: viewData.contractStatusColor.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: AppText(
                    viewData.contractStatusLabel,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: viewData.contractStatusColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),

          // Device Box container
          _buildDeviceBox(context),
          const SizedBox(height: 14),

          // Metadata key-value rows according to variant
          ..._buildMetadataRows(context),
        ],
      ),
    );
  }

  Widget _buildDeviceBox(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final boxBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : const Color(0xFFF9FAFD);

    final bookedList = contract.bookedDevices;

    // Check if combo or multiple devices
    if (viewData.variant == NotificationDetailVariant.signed && bookedList.length > 1) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: boxBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnails row with "+1 phụ kiện" badge
            Row(
              children: [
                _buildThumbnail(context, contract.deviceImageUrl),
                const SizedBox(width: 8),
                _buildThumbnail(context, null),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(
                    '+1 phụ kiện',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppText(
              metadata?['comboTitle']?.toString() ??
                  (contract.deviceName.isNotEmpty
                      ? contract.deviceName
                      : 'Bộ thiết bị quay phim'),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            if (metadata?['accessories'] != null) ...[
              const SizedBox(height: 3),
              AppText(
                metadata!['accessories'].toString(),
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      );
    }

    // Default single or listed devices
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          if (bookedList.isNotEmpty)
            for (int i = 0; i < bookedList.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThumbnail(context, contract.deviceImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          bookedList[i].name,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(height: 3),
                        _buildVariantSpecificSubtitles(context, i),
                      ],
                    ),
                  ),
                ],
              ),
              if (i < bookedList.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    height: 1,
                  ),
                ),
            ]
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(context, contract.deviceImageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        contract.deviceName.isNotEmpty
                            ? contract.deviceName
                            : 'Thiết bị hợp đồng',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(height: 3),
                      _buildVariantSpecificSubtitles(context, 0),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildVariantSpecificSubtitles(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (viewData.variant) {
      case NotificationDetailVariant.awaitingSignature:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata?['insurance'] != null)
              AppText(
                metadata!['insurance'].toString(),
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              )
            else
              AppText(
                '${contract.rentalDays} ngày thuê',
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            const SizedBox(height: 2),
            AppText(
              metadata?['depositText']?.toString() ??
                  'Tiền cọc: ${NumberFormat('#,###', 'vi_VN').format(contract.deposit)}đ',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ],
        );

      case NotificationDetailVariant.renting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (metadata?['lensInfo'] != null)
              AppText(
                metadata!['lensInfo'].toString(),
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            const SizedBox(height: 2),
            AppText(
              metadata?['insuranceNote']?.toString() ?? 'Bảo hiểm kích hoạt',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF52C41A),
            ),
          ],
        );

      case NotificationDetailVariant.expiringSoon:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              metadata?['rentFrom']?.toString() ??
                  'Thuê từ: ${DateFormat('dd/MM/yyyy').format(contract.pickupDate)}',
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            AppText(
              metadata?['returnLocation']?.toString() ??
                  'Điểm trả: ${contract.branchName}',
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        );

      case NotificationDetailVariant.completed:
        final booked = contract.bookedDevices.isNotEmpty && index < contract.bookedDevices.length
            ? contract.bookedDevices[index]
            : null;
        final qty = booked?.quantity ?? contract.quantity;

        // Resolve serial number ONLY if present
        String? serial;
        if (booked != null && contract.assignedDevices.isNotEmpty) {
          final matching = contract.assignedDevices.where(
            (a) => (a.modelId.isNotEmpty && a.modelId == booked.modelId) && a.serial != null && a.serial!.isNotEmpty,
          ).map((a) => a.serial!).toList();
          if (matching.isNotEmpty) {
            serial = matching.join(', ');
          }
        }
        if (serial == null && contract.assignedDevices.isNotEmpty) {
          if (index < contract.assignedDevices.length && contract.assignedDevices[index].serial != null) {
            serial = contract.assignedDevices[index].serial;
          }
        }
        if (serial == null && metadata?['serial_$index'] != null) {
          serial = metadata!['serial_$index'].toString();
        } else if (serial == null && index == 0 && metadata?['serial'] != null) {
          serial = metadata!['serial'].toString();
        }

        final serialText = (serial != null && serial.isNotEmpty) ? ' • S/N: $serial' : '';
        return AppText(
          'Số lượng: $qty$serialText',
          fontSize: 11,
          color: colorScheme.onSurfaceVariant,
        );

      default:
        return AppText(
          'Số lượng: ${contract.quantity} • ${contract.rentalDays} ngày',
          fontSize: 11,
          color: colorScheme.onSurfaceVariant,
        );
    }
  }

  Widget _buildThumbnail(BuildContext context, String? imageUrl) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.camera_alt_outlined,
                size: 22,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          : Icon(
              Icons.camera_alt_outlined,
              size: 22,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
    );
  }

  List<Widget> _buildMetadataRows(BuildContext context) {
    final list = <Widget>[];

    switch (viewData.variant) {
      case NotificationDetailVariant.awaitingSignature:
        final pickupStr = DateFormat('dd/MM/yyyy').format(contract.pickupDate);
        final returnStr = DateFormat('dd/MM/yyyy').format(contract.returnDate);
        final isExpired = metadata?['isExpired'] == true;

        list.add(_buildRow(context, 'Thời gian thuê', '$pickupStr - $returnStr'));
        list.add(_buildRow(
            context,
            'Phương thức ký',
            contract.signingMethod ?? 'Ký điện tử & Xác thực OTP'));
        list.add(_buildRow(
          context,
          'Hạn chót ký',
          metadata?['signingDeadline']?.toString() ?? '10:30 (còn 15 phút)',
          valueColor: isExpired ? const Color(0xFFFF4D4F) : const Color(0xFFFAAD14),
          isBold: true,
        ));
        break;

      case NotificationDetailVariant.signed:
        list.add(_buildRow(
          context,
          'Thời hạn thuê',
          metadata?['rentalPeriod']?.toString() ??
              '${DateFormat('dd/MM/yyyy').format(contract.pickupDate)} - ${DateFormat('dd/MM/yyyy').format(contract.returnDate)} (${contract.rentalDays} ngày)',
        ));
        list.add(_buildRow(
          context,
          'Trạng thái cọc',
          metadata?['depositStatus']?.toString() ??
              'Đã thanh toán (${NumberFormat('#,###', 'vi_VN').format(contract.deposit)}đ)',
          valueColor: const Color(0xFF52C41A),
          isBold: true,
        ));
        break;

      case NotificationDetailVariant.renting:
        list.add(_buildRow(
          context,
          'Thời gian bắt đầu',
          metadata?['actualStart']?.toString() ??
              DateFormat('dd/MM/yyyy • HH:mm').format(contract.pickupDate),
        ));
        list.add(_buildRow(
          context,
          'Hạn hoàn trả dự kiến',
          metadata?['expectedReturn']?.toString() ??
              DateFormat('dd/MM/yyyy • HH:mm').format(contract.effectiveReturnDate),
        ));
        list.add(_buildRow(
          context,
          'Tình trạng thiết bị lúc nhận',
          metadata?['condition']?.toString() ?? 'Mới 98% (Đã ký biên bản bàn giao)',
        ));
        break;

      case NotificationDetailVariant.expiringSoon:
        list.add(_buildRow(
          context,
          'Tiền cọc sẽ',
          metadata?['depositNotice']?.toString() ??
              '${NumberFormat('#,###', 'vi_VN').format(contract.deposit)}đ (sau khi kiểm tra)',
          valueColor: const Color(0xFF52C41A),
          isBold: true,
        ));
        break;

      case NotificationDetailVariant.completed:
        // 1. Trạng thái hợp đồng hiện tại
        list.add(_buildRow(
          context,
          'Trạng thái hợp đồng',
          viewData.contractStatusLabel,
          valueColor: viewData.contractStatusColor,
          isBold: true,
        ));

        // 2. Thời gian thuê
        list.add(_buildRow(
          context,
          'Thời gian thuê',
          '${DateFormat('dd/MM/yyyy').format(contract.pickupDate)} - ${DateFormat('dd/MM/yyyy').format(contract.returnDate)} (${contract.rentalDays} ngày)',
        ));

        // 3. Ngày trả dự kiến có hiệu lực nếu cần (khi hợp đồng có gia hạn)
        if (contract.effectiveReturnDate.isAfter(contract.returnDate)) {
          list.add(_buildRow(
            context,
            'Hạn trả sau gia hạn',
            DateFormat('dd/MM/yyyy • HH:mm').format(contract.effectiveReturnDate),
          ));
        }

        // 4. Ngày nhận lại thực tế khi có dữ liệu
        DateTime? actualReturn;
        for (final device in contract.assignedDevices) {
          if (device.returnedAt != null) {
            if (actualReturn == null || device.returnedAt!.isAfter(actualReturn)) {
              actualReturn = device.returnedAt;
            }
          }
        }
        final actualReturnStr = metadata?['actualReturn']?.toString() ??
            (actualReturn != null ? DateFormat('dd/MM/yyyy • HH:mm').format(actualReturn) : null);
        if (actualReturnStr != null) {
          list.add(_buildRow(
            context,
            'Ngày nhận lại thực tế',
            actualReturnStr,
          ));
        }

        // 5. Chi nhánh khi có
        if (contract.branchName.trim().isNotEmpty) {
          list.add(_buildRow(
            context,
            'Chi nhánh',
            contract.branchName,
          ));
        }
        break;

      default:
        list.add(_buildRow(
          context,
          'Chi nhánh',
          contract.branchName.isNotEmpty ? contract.branchName : 'SNAPLEASE Hub',
        ));
        break;
    }

    return list;
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: AppText(
              label,
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: AppText(
              value,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? colorScheme.onSurface,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
