import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';

class VerificationProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const VerificationProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                totalSteps,
                (index) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color:
                        index < currentStep
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            AppText(
              'Bước $currentStep/$totalSteps',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ],
        ),
      ],
    );
  }
}
