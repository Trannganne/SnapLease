import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/contract_list_repository.dart';
import 'contract_list_event.dart';
import 'contract_list_state.dart';
import 'dart:async';
import '../../../../../core/storage/token_storage.dart';
import '../../../../notification/data/push_service.dart';

class ContractListBloc extends Bloc<ContractListEvent, ContractListState> {
  final ContractListRepository repository;
  int _request = 0;
  StreamSubscription<void>? _push;
  StreamSubscription<void>? _session;

  ContractListBloc({required this.repository})
    : super(const ContractListState()) {
    on<LoadContracts>(_onLoadContracts);
    on<ChangeContractStatusFilter>(_onChangeFilter);
    on<ContractSessionChanged>((event, emit) {
      emit(const ContractListState());
      add(LoadContracts());
    });
    _push = PushService.instance.updates.stream.listen((_) {
      if (!isClosed) add(LoadContracts());
    });
    _session = TokenStorage.changes.listen((_) {
      ++_request;
      if (!isClosed) add(ContractSessionChanged());
    });
  }

  Future<void> _onLoadContracts(
    LoadContracts event,
    Emitter<ContractListState> emit,
  ) async {
    final request = ++_request;
    emit(state.copyWith(status: ContractListStatus.loading));
    try {
      final contracts = await repository.getContracts();
      if (request != _request || emit.isDone) return;
      emit(
        state.copyWith(
          status: ContractListStatus.loaded,
          allContracts: contracts,
        ),
      );
    } catch (e) {
      if (request != _request || emit.isDone) return;
      emit(
        state.copyWith(
          status: ContractListStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    ++_request;
    _push?.cancel();
    _session?.cancel();
    return super.close();
  }

  void _onChangeFilter(
    ChangeContractStatusFilter event,
    Emitter<ContractListState> emit,
  ) {
    emit(state.copyWith(selectedFilter: event.status));
  }
}
