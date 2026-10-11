import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';

class PaymentDepositCard extends StatelessWidget {
  const PaymentDepositCard({super.key});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText(
                'THANH TOÁN & ĐẶT CỌC',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AppText(
                  'Chưa thanh toán',
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRow('Tiền thuê thiết bị (3 ngày)', '1.215.000đ'),
          const SizedBox(height: 8),
          _buildRow('Tiền đặt cọc', '5.000.000đ'),
          const SizedBox(height: 8),
          _buildRow(
            'Gói bảo hiểm RentSafe Basic',
            'Đã bao gồm',
            isHighlight: true,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText(
                'Tổng dự kiến thanh toán',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              AppText(
                '6.215.000đ',
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'Thanh toán trực tiếp bằng chuyển khoản QR nhanh, tiền mặt hoặc thẻ tín dụng/ATM POS tại quầy khi kiểm tra và nhận máy.',
                    color: Colors.blue.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(label, color: Colors.grey.shade700, fontSize: 13),
        AppText(
          value,
          fontWeight: FontWeight.w600,
          color: isHighlight ? Colors.green : null,
          fontSize: 13,
        ),
      ],
    );
  }
}
