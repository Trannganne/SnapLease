import 'package:flutter/material.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';
import '../../services/contract_pdf_service.dart';
import 'contract_section_card.dart';

class ContractPaymentCard extends StatelessWidget {
  final ContractModel contract;
  final VoidCallback onViewPayments;
  const ContractPaymentCard({
    super.key,
    required this.contract,
    required this.onViewPayments,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final payments = contract.payments;
    const money = AppMoneyFormatter();
    String amount(num? value) =>
        value == null ? 'Chưa xác định' : money.format(value);
    return ContractSectionCard(
      title: 'Thanh toán & đặt cọc',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountRow(
            label: 'Tiền thuê (${contract.rentalDays} ngày)',
            value: money.format(contract.rentalTotal),
          ),
          const SizedBox(height: AppSizes.spacingS),
          _AmountRow(
            label: 'Cọc theo hợp đồng',
            value: money.format(contract.deposit),
          ),
          const SizedBox(height: AppSizes.spacingS),
          _AmountRow(
            label: 'Tổng dự kiến',
            value: money.format(contract.totalAmount),
          ),
          const SizedBox(height: 4),
          AppText(
            '* Bao gồm tiền thuê và cọc hoàn trả',
            fontSize: 11,
            color: colors.onSurfaceVariant,
          ),
          const Divider(height: AppSizes.spacingL),
          if (payments.successfulDeposits.isNotEmpty)
            ContractInfoTile(
              label: 'Đã thanh toán cọc',
              value:
                  '${amount(payments.depositPaid)}\n${payments.successfulDeposits.map((p) => p.methodLabel).toSet().join(' • ')}',
              icon: Icons.check_circle_outline,
            )
          else
            AppText(
              payments.complete
                  ? 'Chưa ghi nhận thanh toán cọc thành công'
                  : 'Chưa có đủ thông tin thanh toán cọc',
              fontSize: 13,
            ),
          for (final receipt in payments.receipts.where(
            (p) =>
                p.status == 'THANH_CONG' &&
                p.type != 'TIEN_COC' &&
                p.type != 'HOAN_COC',
          )) ...[
            const SizedBox(height: AppSizes.spacingS),
            ContractInfoTile(
              label: switch (receipt.type) {
                'TIEN_THUE' => 'Tiền thuê đã thanh toán',
                'PHI_GIA_HAN' => 'Phí gia hạn đã thanh toán',
                'PHI_PHAT' => 'Phí phạt đã thanh toán',
                _ => 'Khoản thanh toán khác đã thành công',
              },
              value: '${money.format(receipt.amount)}\n${receipt.methodLabel}',
              icon: Icons.receipt_long_outlined,
            ),
          ],
          for (final receipt in payments.receipts.where(
            (p) => p.type == 'TIEN_COC' && p.status == 'CHO_THANH_TOAN',
          )) ...[
            const SizedBox(height: 8),
            AppText(
              'Cọc chờ xác nhận: ${money.format(receipt.amount)} • ${receipt.methodLabel}',
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ],
          for (final receipt in payments.receipts.where(
            (p) => p.type == 'HOAN_COC',
          )) ...[
            const SizedBox(height: 8),
            AppText(
              '${switch (receipt.status) {
                'DA_HOAN' => 'Đã hoàn cọc',
                'CHO_THANH_TOAN' => 'Chờ hoàn cọc',
                'THAT_BAI' => 'Hoàn cọc thất bại',
                _ => 'Hoàn cọc (${receipt.status})',
              }}: ${money.format(receipt.amount)}',
              fontSize: 12,
            ),
          ],
          const SizedBox(height: AppSizes.spacingM),
          _AmountRow(
            label: 'Tiền cọc còn thiếu',
            value: amount(payments.depositRemaining),
          ),
          const SizedBox(height: AppSizes.spacingS),
          _AmountRow(
            label: 'Tiền thuê còn thiếu',
            value: amount(payments.rentalRemaining),
          ),
          const SizedBox(height: AppSizes.spacingM),
          ContractInfoTile(
            label: 'Tổng còn phải thanh toán',
            value: amount(payments.totalRemaining),
            icon: Icons.account_balance_wallet_outlined,
          ),
          if (payments.totalRemaining == null) ...[
            const SizedBox(height: AppSizes.spacingS),
            AppText(
              'Chưa đủ dữ liệu số dư từ hệ thống. Tổng dự kiến không phải số tiền còn phải thanh toán.',
              fontSize: 12,
              color: colors.onSurfaceVariant,
            ),
          ],
          const SizedBox(height: AppSizes.spacingS),
          TextButton.icon(
            key: const ValueKey('contract-view-payments'),
            onPressed: onViewPayments,
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Xem thanh toán'),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  const _AmountRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelWidget = AppText(
        label,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
      final valueWidget = AppText(
        value,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(13) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelWidget, const SizedBox(height: 4), valueWidget],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: labelWidget),
          const SizedBox(width: 12),
          Flexible(child: valueWidget),
        ],
      );
    },
  );
}
