import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';

class CartEmptyView extends StatelessWidget {
  final VoidCallback onExplorePressed;

  const CartEmptyView({
    super.key,
    required this.onExplorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pageMargin * 2,
          vertical: 40,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 52,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            AppText(
              'Giỏ hàng của bạn đang trống',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              'Hãy khám phá danh mục để chọn dòng máy ảnh và ống kính phù hợp cho nhu cầu của bạn.',
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                text: 'Khám phá thiết bị',
                onPressed: onExplorePressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
