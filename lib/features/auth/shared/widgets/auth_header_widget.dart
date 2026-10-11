import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class AuthHeaderWidget extends StatelessWidget {
  final String badgeText;
  final IconData badgeIcon;
  final String title;
  final String subtitle;
  final Color? badgeBgColor;
  final Color? badgeTextColor;

  const AuthHeaderWidget({
    super.key,
    required this.badgeText,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
    this.badgeBgColor,
    this.badgeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo SNAPLEASE
        Image.asset(
          'assets/images/logo.png',
          height: 48,
          errorBuilder:
              (context, error, stackTrace) => Icon(
                Icons.camera_alt,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 16),
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeBgColor ?? const Color(0xFFE8EBFF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                badgeIcon,
                size: 14,
                color: badgeTextColor ?? Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 4),
              AppText(
                badgeText,
                color: badgeTextColor ?? Theme.of(context).colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Title
        AppText(
          title,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        // Subtitle
        AppText(
          subtitle,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
