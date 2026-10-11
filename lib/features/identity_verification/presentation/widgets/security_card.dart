import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class SecurityCard extends StatelessWidget {
  final bool isCompleted;

  const SecurityCard({super.key, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompleted) ...[
                  AppText(
                    'Bảo mật chuẩn mã hóa AES-256',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                  SizedBox(height: 4),
                  AppText(
                    'Dữ liệu của bạn được mã hóa an toàn và chỉ dùng để lập hợp đồng.',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ] else
                  AppText(
                    'Thông tin của bạn chỉ được sử dụng cho mục đích xác minh danh tính và lập hợp đồng thuê với đối tác SNAPLEASE.',
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
