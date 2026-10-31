import 'package:flutter/material.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';

class BranchChoiceTile extends StatelessWidget {
  final String name, address;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const BranchChoiceTile({
    super.key,
    required this.name,
    required this.address,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingS),
      child: Material(
        color:
            selected ? colors.primary.withValues(alpha: .05) : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          title: AppText(name, fontWeight: FontWeight.w600),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(address, fontSize: 12),
              if (subtitle != null)
                AppText(
                  subtitle!,
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
