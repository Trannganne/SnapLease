import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/contract_pdf_service.dart';
import '../../../data/repositories/contract_repository.dart';
import '../../bloc/contract_detail_cubit.dart';
import 'contract_tracking_state.dart';

class ContractTrackingCubit extends Cubit<ContractTrackingState> {
  final ContractDetailCubit _detail;
  late final StreamSubscription<ContractDetailState> _subscription;
  ContractTrackingCubit(
    ContractModel contract, {
    ContractRepository? repository,
  }) : _detail = ContractDetailCubit(
         contractId: contract.contractId,
         repository: repository ?? ContractRepository(),
       ),
       super(ContractTrackingState(contract: contract)) {
    _subscription = _detail.stream.listen((detail) {
      if (!isClosed) {
        emit(
          ContractTrackingState(
            contract: detail.data?.contract ?? state.contract,
            loading: detail.loading,
            error: detail.error,
            verified: detail.data != null,
          ),
        );
      }
    });
  }

  Future<void> load() => _detail.load();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _detail.close();
    return super.close();
  }
}
