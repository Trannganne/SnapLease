import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class NotificationDemoBanner extends StatelessWidget {
  const NotificationDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAAD14).withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFAAD14).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: Color(0xFFD48806),
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: AppText(
              'DỮ LIỆU MẪU — Bản xem trước giao diện',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD48806),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
