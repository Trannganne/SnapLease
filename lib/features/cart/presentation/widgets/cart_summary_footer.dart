import 'package:flutter/material.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/cart_summary_model.dart';

class CartSummaryFooter extends StatelessWidget {
  final CartSummaryModel summary;
  final VoidCallback onCheckoutPressed;

  const CartSummaryFooter({
    super.key,
    required this.summary,
    required this.onCheckoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const currencyFormatter = AppMoneyFormatter();

    final String depositDisplay =
        summary.totalDeposit != null
            ? currencyFormatter.format(summary.totalDeposit)
            : 'Chưa xác định';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageMargin,
            vertical: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Tiền thuê tạm tính
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AppText(
                      'Tiền thuê tạm tính',
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    currencyFormatter.format(summary.totalRentalPrice),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Divider nhẹ
              Divider(
                height: 1,
                thickness: 0.8,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 8),

              // Row 3: Cọc dự kiến
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: AppText(
                      'Cọc dự kiến',
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    depositDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        summary.totalDeposit != null
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 4: PrimaryButton "Tiếp tục thuê (N)"
              PrimaryButton(
                text:
                    summary.selectedLinesCount > 0
                        ? 'Tiếp tục thuê (${summary.selectedLinesCount})'
                        : 'Tiếp tục thuê',
                onPressed: summary.canCheckout ? onCheckoutPressed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
