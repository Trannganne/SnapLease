import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';

class ImportantNoticeCard extends StatelessWidget {
  const ImportantNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              AppText(
                'LƯU Ý QUAN TRỌNG KHI NHẬN MÁY',
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBullet(
            'Quý khách vui lòng mang theo CCCD bản cứng (hoặc VNeID mức 2) để đối chiếu.',
          ),
          const SizedBox(height: 8),
          _buildBullet(
            'Có mặt tại chi nhánh đúng giờ. Quá 2 tiếng so với giờ hẹn, hợp đồng sẽ tự động hủy.',
          ),
          const SizedBox(height: 8),
          _buildBullet(
            'Kiểm tra kỹ tình trạng ngoại quan và số lượng phụ kiện cùng nhân viên kỹ thuật trước khi rời quầy.',
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, right: 8.0, left: 4.0),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: AppText(text, color: Colors.red.shade900, fontSize: 13),
        ),
      ],
    );
  }
}
