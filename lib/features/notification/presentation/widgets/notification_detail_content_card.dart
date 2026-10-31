import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class NotificationDetailContentCard extends StatelessWidget {
  final String content;

  const NotificationDetailContentCard({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildRichContent(context, content),
    );
  }

  Widget _buildRichContent(BuildContext context, String rawContent) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);

    // Pattern to match contract codes (HD000125, #HD001), duration/times (15 phút, 18:00 hôm nay), money (2.000.000đ, 1.500.000đ)
    final pattern = RegExp(
      r'(#?HD\d+|15 phút|18:00 hôm nay|\d{1,2}:\d{2}\s*(?:hôm nay|ngày mai)?|\d{1,3}(?:\.\d{3})*(?:,\d+)?\s*(?:đ|VND))',
      caseSensitive: false,
    );

    final matches = pattern.allMatches(rawContent);
    if (matches.isEmpty) {
      return AppText(
        rawContent,
        fontSize: 14,
        color: baseColor,
        style: TextStyle(height: 1.55, color: baseColor),
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: rawContent.substring(lastIndex, match.start),
          style: TextStyle(
            color: baseColor,
            fontSize: 14,
            height: 1.55,
            fontFamily: 'Roboto',
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.55,
          fontFamily: 'Roboto',
        ),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < rawContent.length) {
      spans.add(TextSpan(
        text: rawContent.substring(lastIndex),
        style: TextStyle(
          color: baseColor,
          fontSize: 14,
          height: 1.55,
          fontFamily: 'Roboto',
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}
