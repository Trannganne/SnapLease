import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';

class LegalVerificationCard extends StatelessWidget {
  const LegalVerificationCard({super.key});

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
          const AppText(
            'PHÁP LÝ & XÁC THỰC DANH TÍNH',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          const SizedBox(height: 16),
          _buildItem(
            context,
            Icons.description,
            'Hợp đồng điện tử ký số',
            'Mã xác thực: SHA-256 Valid',
            'Xem bản ký',
            () {},
          ),
          const Divider(height: 24),
          _buildItem(
            context,
            Icons.credit_card,
            'Căn cước công dân gắn chip',
            '079201*** • Nguyễn V.',
            'Đã đối soát',
            null,
            isSuccess: true,
          ),
          const Divider(height: 24),
          _buildItem(
            context,
            Icons.security,
            'Bảo hiểm RentSafe Basic',
            'Bảo vệ rơi vỡ, kỹ thuật 80%',
            'Đã kích hoạt',
            null,
            isSuccess: true,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String actionLabel,
    VoidCallback? onAction, {
    bool isSuccess = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title, fontWeight: FontWeight.bold, fontSize: 13),
              const SizedBox(height: 2),
              AppText(
                subtitle,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ],
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          )
        else
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: isSuccess ? Colors.green : Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 4),
              AppText(
                actionLabel,
                color: isSuccess ? Colors.green : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
      ],
    );
  }
}
