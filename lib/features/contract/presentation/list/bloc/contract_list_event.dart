import 'package:equatable/equatable.dart';
import '../../../domain/models/contract_summary_model.dart';

abstract class ContractListEvent extends Equatable {
  const ContractListEvent();

  @override
  List<Object?> get props => [];
}

class LoadContracts extends ContractListEvent {}

class ChangeContractStatusFilter extends ContractListEvent {
  final ContractStatus status;

  const ChangeContractStatusFilter(this.status);

  @override
  List<Object?> get props => [status];
}
