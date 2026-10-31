class ReviewHighlightChip {
  final String id;
  final String label;

  const ReviewHighlightChip({required this.id, required this.label});

  static const List<ReviewHighlightChip> options = [
    ReviewHighlightChip(id: 'image_quality', label: 'Chất lượng hình ảnh tốt'),
    ReviewHighlightChip(
      id: 'stable_operation',
      label: 'Thiết bị hoạt động ổn định',
    ),
    ReviewHighlightChip(id: 'good_appearance', label: 'Ngoại hình tốt'),
    ReviewHighlightChip(id: 'good_battery', label: 'Pin sử dụng tốt'),
    ReviewHighlightChip(id: 'easy_to_use', label: 'Dễ sử dụng'),
  ];

  static List<String> get defaultLabels => options.map((e) => e.label).toList();
}
