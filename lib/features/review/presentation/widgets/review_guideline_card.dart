import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';

class ReviewGuidelineCard extends StatelessWidget {
  const ReviewGuidelineCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4FF),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: Border.all(color: const Color(0xFF91CAFF)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF0958D9), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Chia sẻ trải nghiệm thực tế, sử dụng ngôn ngữ phù hợp và tránh đăng thông tin cá nhân.',
              fontSize: 12.5,
              color: Color(0xFF003EB3),
            ),
          ),
        ],
      ),
    );
  }
}
