class ReviewSubmissionData {
  final String detailId;
  final int rating;
  final String comment;
  final List<String> highlights;
  final List<String> imagePaths;

  const ReviewSubmissionData({
    required this.detailId,
    required this.rating,
    this.comment = '',
    this.highlights = const [],
    this.imagePaths = const [],
  });

  Map<String, dynamic> toApiJson() => {
    'maChiTietHopDong': detailId,
    'soSao': rating,
    if (comment.trim().isNotEmpty) 'nhanXet': comment.trim(),
    'diemNoiBat': highlights,
  };

  Map<String, dynamic> toJson() => {
    'detailId': detailId,
    'rating': rating,
    'comment': comment,
    'highlights': highlights,
    'imagePaths': imagePaths,
  };
}
