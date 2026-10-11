import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class CaptureRequirementsCard extends StatelessWidget {
  const CaptureRequirementsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppText('💡', fontSize: 16),
              const SizedBox(width: 8),
              const AppText(
                'Yêu cầu khi chụp ảnh',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementRow(
            Icons.check_circle,
            'Ảnh đủ 4 góc',
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildRequirementRow(
            Icons.check_circle,
            'Rõ chữ, dễ đọc',
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildRequirementRow(
            Icons.check_circle,
            'Không lóa/chói sáng',
            Colors.green,
          ),
          SizedBox(height: 8),
          _buildRequirementRow(
            Icons.cancel,
            'Không dùng bản photo',
            Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        AppText(text, fontSize: 14),
      ],
    );
  }
}
