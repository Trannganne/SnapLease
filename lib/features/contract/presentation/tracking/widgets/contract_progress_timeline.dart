import 'package:flutter/material.dart';
import '../../../../../core/widgets/app_text.dart';
import '../models/contract_timeline_step.dart';

class ContractProgressTimeline extends StatelessWidget {
  final List<ContractTimelineStep> steps;
  final String title;

  const ContractProgressTimeline({
    super.key,
    required this.steps,
    this.title = 'TIẾN ĐỘ HỢP ĐỒNG',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, fontWeight: FontWeight.bold, fontSize: 14),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (index) {
            final isLast = index == steps.length - 1;
            return _TimelineItem(step: steps[index], isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ContractTimelineStep step;
  final bool isLast;

  const _TimelineItem({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color getIconColor() {
      switch (step.state) {
        case TimelineStepState.completed:
          return Theme.of(context).colorScheme.primary;
        case TimelineStepState.active:
          return Colors.orange;
        case TimelineStepState.pending:
          return Colors.grey.shade400;
        case TimelineStepState.cancelled:
          return Theme.of(context).colorScheme.error;
      }
    }

    IconData getIcon() {
      switch (step.state) {
        case TimelineStepState.completed:
          return Icons.check_circle;
        case TimelineStepState.active:
          return Icons.radio_button_checked;
        case TimelineStepState.pending:
          return Icons.radio_button_unchecked;
        case TimelineStepState.cancelled:
          return Icons.cancel_outlined;
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(getIcon(), color: getIconColor(), size: 20),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        step.state == TimelineStepState.completed
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    step.title,
                    fontWeight:
                        step.state != TimelineStepState.pending
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color:
                        step.state == TimelineStepState.pending
                            ? Colors.grey
                            : null,
                    fontSize: 14,
                  ),
                  if (step.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(
                      step.subtitle,
                      color:
                          step.state == TimelineStepState.pending
                              ? Colors.grey
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ],
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 4),
                    AppText(
                      step.timestamp!,
                      color:
                          step.state == TimelineStepState.cancelled
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
