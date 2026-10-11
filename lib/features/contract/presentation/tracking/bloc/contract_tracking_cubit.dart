import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/contract_pdf_service.dart';
import '../models/contract_tracking_status.dart';
import 'contract_tracking_state.dart';

class ContractTrackingCubit extends Cubit<ContractTrackingState> {
  ContractTrackingCubit(ContractModel contract)
    : super(ContractTrackingState(contract: contract));

  void changeStatus(ContractTrackingStatus newStatus) {
    emit(state.copyWith(status: newStatus));
  }
}
