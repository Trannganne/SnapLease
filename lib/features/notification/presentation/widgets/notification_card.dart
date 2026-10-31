import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/notification_item_model.dart';

class NotificationCard extends StatelessWidget {
  final NotificationItemModel item;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

  const NotificationCard({
    super.key,
    required this.item,
    this.onTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visual = _getVisualConfig(item.rawType, colorScheme);

    // Unread background has subtle accent tint, read is neutral surface
    final cardBgColor =
        item.isRead
            ? colorScheme.surface
            : colorScheme.primary.withValues(alpha: 0.04);

    final borderColor =
        item.isRead
            ? colorScheme.outlineVariant.withValues(alpha: 0.4)
            : colorScheme.primary.withValues(alpha: 0.25);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Icon inside light circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, color: visual.iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Middle & Right: content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with optional unread dot
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppText(
                          item.displayTitle,
                          fontSize: 14,
                          fontWeight:
                              item.isRead ? FontWeight.w600 : FontWeight.bold,
                          color: colorScheme.onSurface,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Description text with highlights for codes / amounts
                  _buildContentText(context, item.content),
                  const SizedBox(height: 10),

                  // Bottom row: time on left, action link on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: AppText(
                                _formatTime(item.sentAt),
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.actionText != null && onActionTap != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onActionTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  item.actionText!,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentText(BuildContext context, String content) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurfaceVariant;

    // Pattern to highlight contract IDs (e.g. #HD001), amounts (e.g. 2.000.000đ)
    final regex = RegExp(r'(#HD\w+|\d{1,3}(?:\.\d{3})*(?:,\d+)?\s*(?:đ|VND))');
    final matches = regex.allMatches(content);

    if (matches.isEmpty) {
      return AppText(
        content,
        fontSize: 13,
        color: baseColor,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: TextStyle(
              color: baseColor,
              fontSize: 13,
              fontFamily: 'Roboto',
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: TextStyle(
            color: baseColor,
            fontSize: 13,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24 && time.day == now.day) {
      final hourStr = time.hour.toString().padLeft(2, '0');
      final minuteStr = time.minute.toString().padLeft(2, '0');
      return '$hourStr:$minuteStr';
    } else {
      final hourStr = time.hour.toString().padLeft(2, '0');
      final minuteStr = time.minute.toString().padLeft(2, '0');
      final dayStr = time.day.toString().padLeft(2, '0');
      final monthStr = time.month.toString().padLeft(2, '0');
      return '$hourStr:$minuteStr - $dayStr/$monthStr';
    }
  }

  _NotificationVisualConfig _getVisualConfig(
    String rawType,
    ColorScheme colorScheme,
  ) {
    switch (rawType.toUpperCase()) {
      case 'GIU_CHO':
      case 'RESERVATION':
        return const _NotificationVisualConfig(
          icon: Icons.access_time_rounded,
          iconColor: Color(0xFFFA8C16), // Orange
          backgroundColor: Color(0xFFFFF7E6),
        );
      case 'HOP_DONG':
      case 'CONTRACT':
        return const _NotificationVisualConfig(
          icon: Icons.article_outlined,
          iconColor: Color(0xFF13C2C2), // Teal
          backgroundColor: Color(0xFFE6FFFB),
        );
      case 'THANH_TOAN':
      case 'PAYMENT':
        return _NotificationVisualConfig(
          icon: Icons.account_balance_wallet_outlined,
          iconColor: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
        );
      case 'BAN_GIAO':
      case 'HANDOVER':
        return const _NotificationVisualConfig(
          icon: Icons.inventory_2_outlined,
          iconColor: Color(0xFF2F54EB), // Indigo
          backgroundColor: Color(0xFFF0F5FF),
        );
      case 'GIA_HAN':
      case 'EXTENSION':
        return const _NotificationVisualConfig(
          icon: Icons.event_available_outlined,
          iconColor: Color(0xFF52C41A), // Green
          backgroundColor: Color(0xFFF6FFED),
        );
      case 'HOAN_TIEN':
      case 'REFUND':
        return const _NotificationVisualConfig(
          icon: Icons.currency_exchange_outlined,
          iconColor: Color(0xFF722ED1), // Purple
          backgroundColor: Color(0xFFF9F0FF),
        );
      case 'XAC_MINH_GIAY_TO':
        return const _NotificationVisualConfig(
          icon: Icons.verified_user_outlined,
          iconColor: Color(0xFF1890FF), // Blue
          backgroundColor: Color(0xFFE6F7FF),
        );
      default:
        // Neutral card for unknown types
        return _NotificationVisualConfig(
          icon: Icons.notifications_none_outlined,
          iconColor: colorScheme.onSurfaceVariant,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
        );
    }
  }
}

class _NotificationVisualConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  const _NotificationVisualConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}
