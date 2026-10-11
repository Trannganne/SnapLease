import 'package:equatable/equatable.dart';

class RentalConfirmationState extends Equatable {
  final bool isConfirmed;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String branchId;

  // Mock constant properties for now, but these could be passed in/updated
  final int rentalPricePerDay = 450000;
  final int discountPercent = 10;
  final int deposit = 5000000;

  const RentalConfirmationState({
    this.isConfirmed = false,
    required this.pickupDate,
    required this.returnDate,
    required this.branchId,
  });

  int get rentalDays {
    final difference = returnDate.difference(pickupDate).inDays;
    return difference > 0 ? difference : 1;
  }

  int get subtotal => rentalPricePerDay * rentalDays;
  int get discountAmount => (subtotal * discountPercent / 100).round();
  int get rentalAfterDiscount => subtotal - discountAmount;
  int get totalPayment => rentalAfterDiscount + deposit;

  RentalConfirmationState copyWith({
    bool? isConfirmed,
    DateTime? pickupDate,
    DateTime? returnDate,
    String? branchId,
  }) {
    return RentalConfirmationState(
      isConfirmed: isConfirmed ?? this.isConfirmed,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      branchId: branchId ?? this.branchId,
    );
  }

  @override
  List<Object?> get props => [isConfirmed, pickupDate, returnDate, branchId];
}
