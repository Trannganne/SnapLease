import 'package:equatable/equatable.dart';

abstract class RentalConfirmationEvent extends Equatable {
  const RentalConfirmationEvent();

  @override
  List<Object?> get props => [];
}

class ToggleConfirmation extends RentalConfirmationEvent {
  final bool isConfirmed;
  const ToggleConfirmation(this.isConfirmed);

  @override
  List<Object?> get props => [isConfirmed];
}

class UpdateRentalPeriod extends RentalConfirmationEvent {
  final DateTime pickupDate;
  final DateTime returnDate;

  const UpdateRentalPeriod({
    required this.pickupDate,
    required this.returnDate,
  });

  @override
  List<Object?> get props => [pickupDate, returnDate];
}

class UpdateBranch extends RentalConfirmationEvent {
  final String branchId;
  const UpdateBranch(this.branchId);

  @override
  List<Object?> get props => [branchId];
}
