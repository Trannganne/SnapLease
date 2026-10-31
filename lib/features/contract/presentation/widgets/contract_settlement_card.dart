import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/models/handover_models.dart';
import '../../domain/models/settlement_view.dart';
import 'package:rentcam/core/widgets/app_text.dart';
import 'contract_section_card.dart';

class ContractSettlementCard extends StatelessWidget {
  final List<AssignedContractDevice> devices;
  final SettlementView? settlement;
  final VoidCallback onOpen;
  const ContractSettlementCard({
    super.key,
    required this.devices,
    required this.settlement,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final v = settlement;
    final received = devices.where((d) => d.returnedAt != null).length;
    String label;
    if (v?.isComplete == true) {
      label = 'Hợp đồng đã hoàn thành';
    } else if (v?.isFinal == true) {
      String money(num x) => '${NumberFormat('#,###', 'vi_VN').format(x)}đ';
      label =
          v!.collectionRemaining != null && v.collectionRemaining! > 0
              ? 'Còn phải trả ${money(v.collectionRemaining!)}'
              : v.refundRemaining != null && v.refundRemaining! > 0
              ? 'Còn phải hoàn ${money(v.refundRemaining!)}'
              : v.refundEntitlement != null && v.refundEntitlement! > 0
              ? 'Theo dõi khoản hoàn và xác nhận nhận tiền'
              : v.collectionRemaining == 0 && v.refundEntitlement == 0
              ? 'Không phát sinh thu/hoàn'
              : 'Xem kết quả đối soát';
    } else {
      label =
          devices.isEmpty
              ? 'Chưa có dữ liệu nhận trả'
              : received < devices.length
              ? 'Đã nhận $received/${devices.length} thiết bị; chưa có quyết toán cuối'
              : 'Đã nhận đủ; đang kiểm tra/lập quyết toán';
    }
    return ContractSectionCard(
      title: 'Hoàn trả & quyết toán',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(label, fontSize: 13),
          TextButton(onPressed: onOpen, child: const Text('Xem quyết toán')),
        ],
      ),
    );
  }
}
