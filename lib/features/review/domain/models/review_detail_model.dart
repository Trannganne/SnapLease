class ReviewDetailModel {
  final String reviewId;
  final String detailId;
  final int rating;
  final String comment;
  final List<String> highlights;
  final List<String> imageUrls;
  final String reviewerName;
  final String? reviewerAvatar;
  final DateTime reviewedAt;
  final bool isVerifiedRenter;
  final bool isApproved;
  final bool isPublic;
  final String? moderationStatus;
  final String? moderationNote;
  final List<String> imageIds;

  const ReviewDetailModel({
    required this.reviewId,
    required this.detailId,
    required this.rating,
    this.comment = '',
    this.highlights = const [],
    this.imageUrls = const [],
    required this.reviewerName,
    this.reviewerAvatar,
    required this.reviewedAt,
    this.isVerifiedRenter = true,
    this.isApproved = false,
    this.isPublic = false,
    this.moderationStatus,
    this.moderationNote,
    this.imageIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'reviewId': reviewId,
    'detailId': detailId,
    'rating': rating,
    'comment': comment,
    'highlights': highlights,
    'imageUrls': imageUrls,
    'reviewerName': reviewerName,
    'reviewerAvatar': reviewerAvatar,
    'reviewedAt': reviewedAt.toIso8601String(),
    'isVerifiedRenter': isVerifiedRenter,
    'isApproved': isApproved,
    'isPublic': isPublic,
  };

  factory ReviewDetailModel.fromJson(Map<String, dynamic> json) =>
      ReviewDetailModel(
        reviewId: json['reviewId'] as String? ?? '',
        detailId: json['detailId'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 5,
        comment: json['comment'] as String? ?? '',
        highlights: List<String>.from(json['highlights'] as List? ?? []),
        imageUrls: List<String>.from(json['imageUrls'] as List? ?? []),
        reviewerName: json['reviewerName'] as String? ?? 'Khách thuê',
        reviewerAvatar: json['reviewerAvatar'] as String?,
        reviewedAt:
            DateTime.tryParse(json['reviewedAt'] as String? ?? '') ??
            DateTime.now(),
        isVerifiedRenter: json['isVerifiedRenter'] as bool? ?? true,
        isApproved: json['isApproved'] as bool? ?? false,
        isPublic: json['isPublic'] as bool? ?? false,
      );
}
