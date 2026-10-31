import 'package:flutter/material.dart';
import 'app_text.dart';
import 'primary_button.dart';

Future<bool?> showAppNoticeDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String? secondaryAction,
  IconData? icon,
  Color? iconColor,
}) => showDialog<bool>(
  context: context,
  builder:
      (dialogContext) => AlertDialog(
        title:
            icon == null
                ? AppText(title, fontWeight: FontWeight.bold)
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: (iconColor ??
                              Theme.of(context).colorScheme.primary)
                          .withValues(alpha: .12),
                      radius: 26,
                      child: Icon(
                        icon,
                        color:
                            iconColor ?? Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppText(
                      title,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        content: SingleChildScrollView(
          child: AppText(
            message,
            textAlign: icon == null ? null : TextAlign.center,
          ),
        ),
        actions: [
          if (secondaryAction == null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: AppText(action),
            )
          else ...[
            PrimaryButton(
              text: action,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: AppText(secondaryAction),
              ),
            ),
          ],
        ],
      ),
);
