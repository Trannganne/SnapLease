import 'package:flutter/material.dart';
import '../../domain/models/notification_item_model.dart';
import '../../../contract/services/contract_pdf_service.dart';
import '../../../contract/domain/models/extension_models.dart';

enum NotificationDetailVariant {
  awaitingSignature, // Variant A: Hợp đồng đang chờ ký
  signed, // Variant B: Hợp đồng đã được ký thành công
  renting, // Variant C: Hợp đồng đã bắt đầu
  expiringSoon, // Variant D: Hợp đồng sắp đến hạn trả
  completed, // Biến thể hoàn tất: Hợp đồng đã hoàn thành
  generic, // Thông báo chung khác
}

class NotificationDetailViewData {
  final NotificationDetailVariant variant;
  final String title;
  final String timeFormatted;
  final String? subtitleBadgeText;
  final Color? subtitleBadgeColor;
  final Color? subtitleBadgeBgColor;
  final IconData headerIcon;
  final Color headerIconColor;
  final Color headerIconBgColor;
  final String? warningTitle;
  final String? warningTime;
  final String? warningRemaining;
  final bool isOverdue;
  final String ctaText;
  final IconData? ctaIcon;
  final bool isCtaEnabled;
  final String contractStatusLabel;
  final Color contractStatusColor;
  final Color contractStatusBgColor;

  const NotificationDetailViewData({
    required this.variant,
    required this.title,
    required this.timeFormatted,
    this.subtitleBadgeText,
    this.subtitleBadgeColor,
    this.subtitleBadgeBgColor,
    required this.headerIcon,
    required this.headerIconColor,
    required this.headerIconBgColor,
    this.warningTitle,
    this.warningTime,
    this.warningRemaining,
    this.isOverdue = false,
    required this.ctaText,
    this.ctaIcon,
    this.isCtaEnabled = true,
    required this.contractStatusLabel,
    required this.contractStatusColor,
    required this.contractStatusBgColor,
  });

  factory NotificationDetailViewData.from({
    required BuildContext context,
    required NotificationItemModel item,
    ContractModel? contract,
    String? explicitVariant,
    DateTime? signingDeadline,
    DateTime? effectiveReturnTime,
    bool isSigningExpired = false,
    bool isReturnOverdue = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (item.isExtension && explicitVariant == null) {
      final id = item.resolveAppendixId(contract?.extensions ?? []);
      ExtensionSummary? extension;
      for (final row in contract?.extensions ?? <Map<String, dynamic>>[]) {
        if (id != null && row['maPhuLuc'] == id) {
          extension = ExtensionSummary.fromJson(row);
        }
      }
      final label = extension?.label ?? 'Cập nhật yêu cầu gia hạn';
      return NotificationDetailViewData(
        variant: NotificationDetailVariant.generic,
        title: label,
        timeFormatted: _formatDateTime(item.sentAt),
        headerIcon: Icons.event_note_outlined,
        headerIconColor: theme.colorScheme.primary,
        headerIconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ctaText:
            id == null
                ? 'Xem các yêu cầu gia hạn'
                : extension?.status == 'CHO_KY'
                ? 'Xem phụ lục gia hạn'
                : 'Xem kết quả gia hạn',
        ctaIcon: Icons.description_outlined,
        isCtaEnabled: contract != null,
        contractStatusLabel: label,
        contractStatusColor: theme.colorScheme.primary,
        contractStatusBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      );
    }

    // Resolve variant
    NotificationDetailVariant resolvedVariant;
    if (explicitVariant != null &&
        explicitVariant.isNotEmpty &&
        explicitVariant.toUpperCase() != 'STATUS_MISMATCH') {
      switch (explicitVariant.toUpperCase()) {
        case 'A':
        case 'CHO_KY':
          resolvedVariant = NotificationDetailVariant.awaitingSignature;
          break;
        case 'B':
        case 'DA_KY':
          resolvedVariant = NotificationDetailVariant.signed;
          break;
        case 'C':
        case 'DANG_THUE':
        case 'BAT_DAU':
          resolvedVariant = NotificationDetailVariant.renting;
          break;
        case 'D':
        case 'SAP_HET_HAN':
          resolvedVariant = NotificationDetailVariant.expiringSoon;
          break;
        case 'E':
        case 'HOAN_THANH':
        case 'COMPLETED':
          resolvedVariant = NotificationDetailVariant.completed;
          break;
        default:
          resolvedVariant = NotificationDetailVariant.generic;
      }
    } else if (contract != null && contract.status != null) {
      resolvedVariant = _resolveFromContractStatus(contract);
    } else {
      final titleLower = item.title.toLowerCase();
      final contentLower = item.content.toLowerCase();
      if (titleLower.contains('chờ ký') ||
          contentLower.contains('ký điện tử')) {
        resolvedVariant = NotificationDetailVariant.awaitingSignature;
      } else if (titleLower.contains('đã ký') ||
          titleLower.contains('ký thành công') ||
          contentLower.contains('chữ ký số')) {
        resolvedVariant = NotificationDetailVariant.signed;
      } else if (titleLower.contains('đã bắt đầu') ||
          item.rawType == 'BAN_GIAO' ||
          contentLower.contains('bắt đầu có hiệu lực')) {
        resolvedVariant = NotificationDetailVariant.renting;
      } else if (titleLower.contains('đến hạn') ||
          titleLower.contains('hết hạn') ||
          contentLower.contains('kết thúc lúc')) {
        resolvedVariant = NotificationDetailVariant.expiringSoon;
      } else if (titleLower.contains('hoàn thành') ||
          titleLower.contains('hoàn tất') ||
          contentLower.contains('hoàn thành') ||
          contentLower.contains('hoàn tất')) {
        resolvedVariant = NotificationDetailVariant.completed;
      } else {
        resolvedVariant = NotificationDetailVariant.generic;
      }
    }

    final timeFormatted = _formatDateTime(item.sentAt);

    switch (resolvedVariant) {
      case NotificationDetailVariant.awaitingSignature:
        return NotificationDetailViewData(
          variant: resolvedVariant,
          title: item.title.isNotEmpty ? item.title : 'Hợp đồng đang chờ ký',
          timeFormatted: timeFormatted,
          subtitleBadgeText: !item.isRead ? 'Mới' : null,
          subtitleBadgeColor: const Color(0xFF1D39C4),
          subtitleBadgeBgColor: const Color(0xFFE6F7FF),
          headerIcon: Icons.edit_outlined,
          headerIconColor: const Color(0xFFFAAD14),
          headerIconBgColor:
              isDark ? const Color(0xFF382D16) : const Color(0xFFFFFBE6),
          ctaText: isSigningExpired ? 'Hợp đồng đã hết hạn ký' : 'Ký hợp đồng',
          ctaIcon: isSigningExpired ? null : Icons.edit_outlined,
          isCtaEnabled: !isSigningExpired,
          contractStatusLabel: '• Chờ ký',
          contractStatusColor: const Color(0xFFD48806),
          contractStatusBgColor:
              isDark ? const Color(0xFF3B2E1E) : const Color(0xFFFFFBE6),
        );

      case NotificationDetailVariant.signed:
        return NotificationDetailViewData(
          variant: resolvedVariant,
          title:
              item.title.isNotEmpty
                  ? item.title
                  : 'Hợp đồng đã được ký thành công',
          timeFormatted: timeFormatted,
          subtitleBadgeText: 'Đã xác thực',
          subtitleBadgeColor: const Color(0xFF52C41A),
          subtitleBadgeBgColor:
              isDark ? const Color(0xFF1E3A24) : const Color(0xFFF6FFED),
          headerIcon: Icons.check_circle_outline,
          headerIconColor: const Color(0xFF52C41A),
          headerIconBgColor:
              isDark ? const Color(0xFF19361E) : const Color(0xFFF6FFED),
          ctaText: 'Xem hợp đồng',
          ctaIcon: Icons.description_outlined,
          isCtaEnabled: true,
          contractStatusLabel: '• Đã ký',
          contractStatusColor: const Color(0xFF52C41A),
          contractStatusBgColor:
              isDark ? const Color(0xFF1E3A24) : const Color(0xFFF6FFED),
        );

      case NotificationDetailVariant.renting:
        return NotificationDetailViewData(
          variant: resolvedVariant,
          title: item.title.isNotEmpty ? item.title : 'Hợp đồng đã bắt đầu',
          timeFormatted: timeFormatted,
          subtitleBadgeText: item.isRead ? 'Đã đọc' : 'Mới',
          subtitleBadgeColor:
              item.isRead
                  ? theme.colorScheme.onSurfaceVariant
                  : const Color(0xFF1D39C4),
          subtitleBadgeBgColor:
              item.isRead
                  ? theme.colorScheme.surfaceContainerHighest
                  : const Color(0xFFE6F7FF),
          headerIcon: Icons.photo_camera_outlined,
          headerIconColor: const Color(0xFF2F54EB),
          headerIconBgColor:
              isDark ? const Color(0xFF1E284A) : const Color(0xFFF0F5FF),
          ctaText: 'Theo dõi hợp đồng',
          ctaIcon: Icons.track_changes_outlined,
          isCtaEnabled: true,
          contractStatusLabel: '• Đang thuê',
          contractStatusColor: const Color(0xFF2F54EB),
          contractStatusBgColor:
              isDark ? const Color(0xFF1E284A) : const Color(0xFFF0F5FF),
        );

      case NotificationDetailVariant.expiringSoon:
        final now = DateTime.now();
        final due =
            effectiveReturnTime ??
            contract?.effectiveReturnDate ??
            DateTime(now.year, now.month, now.day, 18, 0);

        final overdue = isReturnOverdue || now.isAfter(due);
        String remainingText;
        if (overdue) {
          remainingText = 'Đã quá hạn trả';
        } else {
          final diff = due.difference(now);
          final hours = diff.inHours;
          final minutes = diff.inMinutes.remainder(60);
          remainingText =
              'Còn lại: ${hours.toString().padLeft(2, '0')} giờ ${minutes.toString().padLeft(2, '0')} phút';
        }

        final dueFormatted = _formatDueTime(due);

        return NotificationDetailViewData(
          variant: resolvedVariant,
          title:
              item.title.isNotEmpty ? item.title : 'Hợp đồng sắp đến hạn trả',
          timeFormatted: timeFormatted,
          subtitleBadgeText: 'Quan trọng',
          subtitleBadgeColor: const Color(0xFFFF4D4F),
          subtitleBadgeBgColor:
              isDark ? const Color(0xFF3E1E20) : const Color(0xFFFFF1F0),
          headerIcon: Icons.access_time_rounded,
          headerIconColor: const Color(0xFFFF4D4F),
          headerIconBgColor:
              isDark ? const Color(0xFF3E1E20) : const Color(0xFFFFF1F0),
          warningTitle: 'THỜI HẠN HOÀN TRẢ',
          warningTime: dueFormatted,
          warningRemaining: remainingText,
          isOverdue: overdue,
          ctaText: 'Xem hợp đồng',
          ctaIcon: Icons.description_outlined,
          isCtaEnabled: true,
          contractStatusLabel: overdue ? '• Quá hạn' : '• Sắp hết hạn',
          contractStatusColor: const Color(0xFFFF4D4F),
          contractStatusBgColor:
              isDark ? const Color(0xFF3E1E20) : const Color(0xFFFFF1F0),
        );

      case NotificationDetailVariant.completed:
        return NotificationDetailViewData(
          variant: resolvedVariant,
          title: item.title.isNotEmpty ? item.title : 'Hợp đồng đã hoàn thành',
          timeFormatted: timeFormatted,
          subtitleBadgeText: 'Hoàn thành',
          subtitleBadgeColor: const Color(0xFF52C41A),
          subtitleBadgeBgColor:
              isDark ? const Color(0xFF1E3A24) : const Color(0xFFF6FFED),
          headerIcon: Icons.check_circle_outline,
          headerIconColor: const Color(0xFF52C41A),
          headerIconBgColor:
              isDark ? const Color(0xFF19361E) : const Color(0xFFF6FFED),
          ctaText: 'Xem chi tiết hợp đồng',
          ctaIcon: Icons.description_outlined,
          isCtaEnabled: true,
          contractStatusLabel: '• Hoàn tất',
          contractStatusColor: const Color(0xFF52C41A),
          contractStatusBgColor:
              isDark ? const Color(0xFF1E3A24) : const Color(0xFFF6FFED),
        );

      case NotificationDetailVariant.generic:
        return NotificationDetailViewData(
          variant: resolvedVariant,
          title: item.title,
          timeFormatted: timeFormatted,
          subtitleBadgeText: !item.isRead ? 'Mới' : null,
          subtitleBadgeColor: theme.colorScheme.primary,
          subtitleBadgeBgColor: theme.colorScheme.primary.withValues(
            alpha: 0.1,
          ),
          headerIcon: Icons.notifications_none_rounded,
          headerIconColor: theme.colorScheme.primary,
          headerIconBgColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          ctaText: 'Quay lại',
          ctaIcon: Icons.arrow_back,
          isCtaEnabled: true,
          contractStatusLabel: 'Thông báo',
          contractStatusColor: theme.colorScheme.onSurfaceVariant,
          contractStatusBgColor: theme.colorScheme.surfaceContainerHighest,
        );
    }
  }

  static String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return 'Hôm nay • $hour:$minute';
    }
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year} • $hour:$minute';
  }

  static String _formatDueTime(DateTime time) {
    final now = DateTime.now();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return 'Hôm nay • $hour:$minute';
    }
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    return '$day/$month/${time.year} • $hour:$minute';
  }

  static NotificationDetailVariant _resolveFromContractStatus(
    ContractModel contract,
  ) {
    final s = (contract.status ?? '').toUpperCase();
    if (s == 'CHO_KY') {
      return NotificationDetailVariant.awaitingSignature;
    } else if (s == 'DA_KY' || s == 'CHO_BAN_GIAO') {
      return NotificationDetailVariant.signed;
    } else if (s == 'DANG_THUE') {
      final now = DateTime.now();
      final due = contract.effectiveReturnDate;
      if (due.difference(now).inHours <= 24) {
        return NotificationDetailVariant.expiringSoon;
      } else {
        return NotificationDetailVariant.renting;
      }
    } else if (s == 'CHO_HOAN_TRA') {
      return NotificationDetailVariant.expiringSoon;
    } else if (s == 'HOAN_THANH') {
      return NotificationDetailVariant.completed;
    } else {
      return NotificationDetailVariant.generic;
    }
  }
}
