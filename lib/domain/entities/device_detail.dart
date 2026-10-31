class DeviceDetail {
  final String id;
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final String pricePerDay;
  final int pricePerDayInt;
  final int availableQuantity;
  final List<String> images;
  final List<String> badges;
  final String description;
  final String deviceValue;
  final String depositRate;
  final String estimatedDeposit;

  // Rental Dates
  final String pickupDate;
  final String pickupTime;
  final String returnDate;
  final String returnTime;
  final int rentalDays;

  // Price Summary
  final String subtotal;
  final String discountPercent;
  final String discountAmount;
  final String total;

  final List<BranchAvailability> branches;
  final List<DeviceReview> reviews;

  DeviceDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.pricePerDay,
    required this.pricePerDayInt,
    required this.availableQuantity,
    required this.images,
    required this.badges,
    required this.description,
    required this.deviceValue,
    required this.depositRate,
    required this.estimatedDeposit,
    required this.pickupDate,
    required this.pickupTime,
    required this.returnDate,
    required this.returnTime,
    required this.rentalDays,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.total,
    required this.branches,
    required this.reviews,
  });

  DeviceDetail copyWith({
    String? id,
    String? name,
    String? category,
    double? rating,
    int? reviewCount,
    String? pricePerDay,
    int? pricePerDayInt,
    int? availableQuantity,
    List<String>? images,
    List<String>? badges,
    String? description,
    String? deviceValue,
    String? depositRate,
    String? estimatedDeposit,
    String? pickupDate,
    String? pickupTime,
    String? returnDate,
    String? returnTime,
    int? rentalDays,
    String? subtotal,
    String? discountPercent,
    String? discountAmount,
    String? total,
    List<BranchAvailability>? branches,
    List<DeviceReview>? reviews,
  }) {
    return DeviceDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      pricePerDayInt: pricePerDayInt ?? this.pricePerDayInt,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      images: images ?? this.images,
      badges: badges ?? this.badges,
      description: description ?? this.description,
      deviceValue: deviceValue ?? this.deviceValue,
      depositRate: depositRate ?? this.depositRate,
      estimatedDeposit: estimatedDeposit ?? this.estimatedDeposit,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupTime: pickupTime ?? this.pickupTime,
      returnDate: returnDate ?? this.returnDate,
      returnTime: returnTime ?? this.returnTime,
      rentalDays: rentalDays ?? this.rentalDays,
      subtotal: subtotal ?? this.subtotal,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      branches: branches ?? this.branches,
      reviews: reviews ?? this.reviews,
    );
  }
}

class BranchAvailability {
  final String branchId;
  final String branchName;
  final String address;
  final int availableQuantity;

  BranchAvailability({
    required this.branchId,
    required this.branchName,
    required this.address,
    required this.availableQuantity,
  });
}

class DeviceReview {
  final String userName;
  final String date;
  final double rating;
  final String comment;

  DeviceReview({
    required this.userName,
    required this.date,
    required this.rating,
    required this.comment,
  });
}
