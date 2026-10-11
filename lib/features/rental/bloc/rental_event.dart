import 'package:equatable/equatable.dart';
import '../../../domain/entities/device_detail.dart';

abstract class RentalEvent extends Equatable {
  const RentalEvent();

  @override
  List<Object?> get props => [];
}

class InitializeRental extends RentalEvent {
  final DeviceDetail device;

  const InitializeRental(this.device);

  @override
  List<Object?> get props => [device];
}

class UpdateRentalPeriod extends RentalEvent {
  final DateTime pickupDate;
  final DateTime? returnDate;

  const UpdateRentalPeriod({required this.pickupDate, this.returnDate});

  @override
  List<Object?> get props => [pickupDate, returnDate];
}

class UpdateRentalBranch extends RentalEvent {
  final String branchId;

  const UpdateRentalBranch(this.branchId);

  @override
  List<Object?> get props => [branchId];
}

class ToggleConfirmation extends RentalEvent {
  final bool isConfirmed;

  const ToggleConfirmation(this.isConfirmed);

  @override
  List<Object?> get props => [isConfirmed];
}

class UpdateQuantity extends RentalEvent {
  final int quantity;

  const UpdateQuantity(this.quantity);

  @override
  List<Object?> get props => [quantity];
}

class FetchAvailabilityAndQuote extends RentalEvent {
  const FetchAvailabilityAndQuote();
}

class CreateContract extends RentalEvent {
  const CreateContract();
}

class CreateReservation extends RentalEvent {
  const CreateReservation();
}

class CancelReservation extends RentalEvent {
  const CancelReservation();
}

class CheckReservationStatus extends RentalEvent {
  const CheckReservationStatus();
}

class FetchActiveReservation extends RentalEvent {
  const FetchActiveReservation();
}

class ClearRentalState extends RentalEvent {
  const ClearRentalState();
}

class ClearRentalSession extends RentalEvent {
  const ClearRentalSession();
}

class LoadCustomerProfile extends RentalEvent {
  const LoadCustomerProfile();
}
