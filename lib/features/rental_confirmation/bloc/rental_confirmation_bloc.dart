import 'package:flutter_bloc/flutter_bloc.dart';
import 'rental_confirmation_event.dart';
import 'rental_confirmation_state.dart';

class RentalConfirmationBloc
    extends Bloc<RentalConfirmationEvent, RentalConfirmationState> {
  RentalConfirmationBloc()
    : super(
        RentalConfirmationState(
          pickupDate: DateTime(2026, 9, 20, 9, 0),
          returnDate: DateTime(2026, 9, 23, 18, 0),
          branchId: 'branch_1',
        ),
      ) {
    on<ToggleConfirmation>(_onToggleConfirmation);
    on<UpdateRentalPeriod>(_onUpdateRentalPeriod);
    on<UpdateBranch>(_onUpdateBranch);
  }

  void _onToggleConfirmation(
    ToggleConfirmation event,
    Emitter<RentalConfirmationState> emit,
  ) {
    emit(state.copyWith(isConfirmed: event.isConfirmed));
  }

  void _onUpdateRentalPeriod(
    UpdateRentalPeriod event,
    Emitter<RentalConfirmationState> emit,
  ) {
    emit(
      state.copyWith(
        pickupDate: event.pickupDate,
        returnDate: event.returnDate,
      ),
    );
  }

  void _onUpdateBranch(
    UpdateBranch event,
    Emitter<RentalConfirmationState> emit,
  ) {
    emit(state.copyWith(branchId: event.branchId));
  }
}
