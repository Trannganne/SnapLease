import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../domain/models/extension_models.dart';
import 'contract_section_card.dart';

class ContractExtensionCard extends StatelessWidget {
  final ExtensionSummary extension;
  final DateTime effectiveReturn;
  final VoidCallback? onOpen;
  final String openLabel;
  const ContractExtensionCard({
    super.key,
    required this.extension,
    required this.effectiveReturn,
    this.onOpen,
    this.openLabel = 'Xem yêu cầu gia hạn',
  });

  @override
  Widget build(BuildContext context) {
    final dates = DateFormat('dd/MM/yyyy HH:mm');
    return ContractSectionCard(
      title: extension.label,
      icon: Icons.event_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText('Mã yêu cầu/phụ lục: ${extension.id}'),
          AppText('Hạn trả hiện tại: ${dates.format(effectiveReturn)}'),
          if ((extension.status == 'DA_HIEU_LUC' ||
                  extension.status == 'DA_XAC_NHAN') &&
              extension.previousReturn != null &&
              extension.proposedReturn != null) ...[
            AppText(
              'Ngày trả trước gia hạn: '
              '${dates.format(extension.previousReturn!)}',
            ),
            AppText(
              'Ngày trả sau gia hạn: '
              '${dates.format(extension.proposedReturn!)}',
            ),
          ] else if (extension.proposedReturn != null)
            AppText('Hạn đề nghị: ${dates.format(extension.proposedReturn!)}'),
          if (extension.fee != null)
            AppText(
              '${extension.status == 'TU_CHOI' ? 'Phí dự kiến của yêu cầu bị từ chối' : 'Phí gia hạn'}: ${const AppMoneyFormatter().format(extension.fee)}',
            ),
          if (extension.status == 'CHO_KY' &&
              extension.signingDeadlineUtc != null)
            AppText(
              'Hạn ký: ${dates.format(extension.signingDeadlineUtc!.add(const Duration(hours: 7)))} (giờ Việt Nam)',
            ),
          if (extension.reason?.trim().isNotEmpty == true)
            AppText('Lý do: ${extension.reason}'),
          if (onOpen != null)
            TextButton(onPressed: onOpen, child: Text(openLabel)),
        ],
      ),
    );
  }
}
