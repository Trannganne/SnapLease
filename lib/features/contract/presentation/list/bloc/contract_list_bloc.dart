import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/contract_list_repository.dart';
import 'contract_list_event.dart';
import 'contract_list_state.dart';

class ContractListBloc extends Bloc<ContractListEvent, ContractListState> {
  final ContractListRepository repository;

  ContractListBloc({required this.repository}) : super(const ContractListState()) {
    on<LoadContracts>(_onLoadContracts);
    on<ChangeContractStatusFilter>(_onChangeFilter);
  }

  Future<void> _onLoadContracts(
    LoadContracts event,
    Emitter<ContractListState> emit,
  ) async {
    emit(state.copyWith(status: ContractListStatus.loading));
    try {
      final contracts = await repository.getContracts();
      emit(state.copyWith(
        status: ContractListStatus.loaded,
        allContracts: contracts,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ContractListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onChangeFilter(
    ChangeContractStatusFilter event,
    Emitter<ContractListState> emit,
  ) {
    emit(state.copyWith(selectedFilter: event.status));
  }
}
