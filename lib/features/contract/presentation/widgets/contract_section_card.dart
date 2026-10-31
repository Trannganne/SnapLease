import 'package:flutter/material.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_text.dart';

class ContractSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? tint;
  const ContractSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingM),
      decoration: BoxDecoration(
        color: tint ?? colors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius * 1.5),
        border: Border.all(color: colors.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: AppSizes.spacingS),
              Expanded(
                child: AppText(
                  title,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingM),
          child,
        ],
      ),
    );
  }
}

class ContractInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? action;
  const ContractInfoTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingS + 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary, size: 18),
              const SizedBox(width: AppSizes.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      label,
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    AppText(value, fontSize: 13, fontWeight: FontWeight.w500),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSizes.spacingS),
            action!,
          ],
        ],
      ),
    );
  }
}
