import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/notification_item_model.dart';

class NotificationEmptyView extends StatelessWidget {
  final NotificationCategory category;
  final VoidCallback? onReload;

  const NotificationEmptyView({
    super.key,
    required this.category,
    this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String title;
    String subtitle;
    bool showReloadButton = false;

    switch (category) {
      case NotificationCategory.unread:
        title = 'Không có thông báo chưa đọc';
        subtitle = 'Bạn đã cập nhật và xem hết tất cả thông báo hiện có.';
        break;
      case NotificationCategory.contract:
        title = 'Chưa có thông báo hợp đồng';
        subtitle = 'Các cập nhật về ký hợp đồng, bàn giao và gia hạn sẽ hiển thị tại đây.';
        break;
      case NotificationCategory.payment:
        title = 'Chưa có thông báo thanh toán';
        subtitle = 'Các cập nhật về thanh toán cọc và hoàn trả tiền cọc sẽ hiển thị tại đây.';
        break;
      case NotificationCategory.all:
        title = 'Chưa có thông báo nào';
        subtitle = 'Các thông báo và cập nhật mới nhất về hợp đồng, thanh toán sẽ xuất hiện tại đây.';
        showReloadButton = true;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            AppText(
              title,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              subtitle,
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
            if (showReloadButton && onReload != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 140,
                child: PrimaryButton(
                  text: 'Tải lại',
                  onPressed: onReload,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
