import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_text.dart';
import '../../domain/models/cart_item_model.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';

class CartItemCard extends StatelessWidget {
  final CartItemModel item;
  final bool isEditMode;
  final bool isUpdating;
  final ValueChanged<bool> onSelectionChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDeletePressed;
  final VoidCallback? onPeriodPressed, onBranchPressed;

  const CartItemCard({
    super.key,
    required this.item,
    required this.isEditMode,
    this.isUpdating = false,
    required this.onSelectionChanged,
    required this.onQuantityChanged,
    required this.onDeletePressed,
    this.onPeriodPressed,
    this.onBranchPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const currencyFormatter = AppMoneyFormatter();
    final dateFormatter = DateFormat('HH:mm dd/MM/yyyy');

    final bool canDecrease = item.quantity > 1 && !isUpdating;
    final bool canIncrease =
        (item.maxAvailable == null || item.quantity < item.maxAvailable!) &&
        !isUpdating;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              item.isSelected && item.isAvailable
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: item.isSelected && item.isAvailable ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cột trái: Checkbox và Ảnh thiết bị
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: item.isSelected,
                        activeColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged:
                            item.isAvailable && !isUpdating
                                ? (val) {
                                  if (val != null) {
                                    onSelectionChanged(val);
                                  }
                                }
                                : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color:
                            theme.brightness == Brightness.dark
                                ? Colors.black26
                                : const Color(0xFFF5F6FA),
                        child: AppImage(
                          imageUrl: item.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Cột phải: Thông tin thiết bị
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppText(
                              item.modelName,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isEditMode) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: isUpdating ? null : onDeletePressed,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: colorScheme.error,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Đơn giá thuê
                      Row(
                        children: [
                          AppText(
                            currencyFormatter.format(item.dailyPrice),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          AppText(
                            '/ngày',
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Dòng lịch thuê
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: AppText(
                              'Nhận: ${dateFormatter.format(item.startDate)}\nTrả: ${dateFormatter.format(item.endDate)}',
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Dòng số ngày thuê
                      Padding(
                        padding: const EdgeInsets.only(left: 17),
                        child: AppText(
                          '${item.rentalDays} ngày thuê',
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),

                      if (!item.isAvailable) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: AppText(
                            item.unavailableReason ?? 'Không khả dụng để thuê',
                            fontSize: 11,
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (isEditMode &&
                (onPeriodPressed != null || onBranchPressed != null))
              Wrap(
                spacing: 8,
                children: [
                  if (onPeriodPressed != null)
                    TextButton.icon(
                      onPressed: isUpdating ? null : onPeriodPressed,
                      icon: const Icon(Icons.date_range_outlined, size: 16),
                      label: const Text('Đổi thời gian'),
                    ),
                  if (onBranchPressed != null)
                    TextButton.icon(
                      onPressed: isUpdating ? null : onBranchPressed,
                      icon: const Icon(Icons.storefront_outlined, size: 16),
                      label: const Text('Đổi chi nhánh'),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),

            // Hàng dưới cùng: Stepper bên trái, Tạm tính bên phải
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Stepper
                Container(
                  decoration: BoxDecoration(
                    color:
                        theme.brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStepperButton(
                        icon: Icons.remove,
                        enabled: canDecrease,
                        onTap: () => onQuantityChanged(item.quantity - 1),
                        colorScheme: colorScheme,
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child:
                            isUpdating
                                ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                                : AppText(
                                  '${item.quantity}',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                      ),
                      _buildStepperButton(
                        icon: Icons.add,
                        enabled: canIncrease,
                        onTap: () => onQuantityChanged(item.quantity + 1),
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),

                // Tạm tính dòng
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      'Tạm tính',
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      currencyFormatter.format(item.itemTotalPrice),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color:
              enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
