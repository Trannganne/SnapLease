import 'package:equatable/equatable.dart';
import '../../../domain/models/contract_summary_model.dart';

enum ContractListStatus { initial, loading, loaded, error }

class ContractListState extends Equatable {
  final ContractListStatus status;
  final List<ContractSummaryModel> allContracts;
  final ContractStatus selectedFilter;
  final String? errorMessage;

  const ContractListState({
    this.status = ContractListStatus.initial,
    this.allContracts = const [],
    this.selectedFilter = ContractStatus.all,
    this.errorMessage,
  });

  List<ContractSummaryModel> get filteredContracts {
    if (selectedFilter == ContractStatus.all) return allContracts;
    return allContracts.where((c) => c.status == selectedFilter).toList();
  }

  ContractListState copyWith({
    ContractListStatus? status,
    List<ContractSummaryModel>? allContracts,
    ContractStatus? selectedFilter,
    String? errorMessage,
  }) {
    return ContractListState(
      status: status ?? this.status,
      allContracts: allContracts ?? this.allContracts,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, allContracts, selectedFilter, errorMessage];
}
