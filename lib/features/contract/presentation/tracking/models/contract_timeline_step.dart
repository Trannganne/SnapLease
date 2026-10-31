enum TimelineStepState { completed, active, pending, cancelled }

class ContractTimelineStep {
  final String title;
  final String subtitle;
  final String? timestamp;
  final TimelineStepState state;

  ContractTimelineStep({
    required this.title,
    required this.subtitle,
    this.timestamp,
    required this.state,
  });
}
