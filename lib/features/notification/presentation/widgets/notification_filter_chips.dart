import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/notification_item_model.dart';

class NotificationFilterChips extends StatelessWidget {
  final NotificationCategory selectedCategory;
  final int totalCount;
  final int unreadCount;
  final ValueChanged<NotificationCategory> onCategorySelected;

  const NotificationFilterChips({
    super.key,
    required this.selectedCategory,
    required this.totalCount,
    required this.unreadCount,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(
            context,
            title: 'Tất cả',
            category: NotificationCategory.all,
            badgeCount: totalCount > 0 ? totalCount : null,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            title: 'Chưa đọc',
            category: NotificationCategory.unread,
            badgeCount: unreadCount > 0 ? unreadCount : null,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            title: 'Hợp đồng',
            category: NotificationCategory.contract,
          ),
          const SizedBox(width: 8),
          _buildChip(
            context,
            title: 'Thanh toán',
            category: NotificationCategory.payment,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String title,
    required NotificationCategory category,
    int? badgeCount,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedCategory == category;
    final primaryColor = theme.colorScheme.primary;

    return InkWell(
      onTap: () => onCategorySelected(category),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              title,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppText(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
