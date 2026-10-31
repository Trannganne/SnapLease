import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class NotificationReturnWarningCard extends StatelessWidget {
  final String title;
  final String dueTime;
  final String remainingText;
  final bool isOverdue;

  const NotificationReturnWarningCard({
    super.key,
    this.title = 'THỜI HẠN HOÀN TRẢ',
    required this.dueTime,
    required this.remainingText,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryRed = const Color(0xFFFF4D4F);
    final bgColor = isDark ? const Color(0xFF381F21) : const Color(0xFFFFF2F0);
    final borderColor = isDark ? const Color(0xFF5E272B) : const Color(0xFFFFCCC7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: primaryRed,
                  style: const TextStyle(letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                AppText(
                  dueTime,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                const SizedBox(height: 4),
                AppText(
                  remainingText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryRed,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF4C2427) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryRed.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: primaryRed,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
