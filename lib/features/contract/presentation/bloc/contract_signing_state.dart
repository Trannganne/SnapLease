import 'package:equatable/equatable.dart';
import '../../services/contract_pdf_service.dart';

abstract class ContractSigningState extends Equatable {
  const ContractSigningState();

  @override
  List<Object?> get props => [];
}

class ContractSigningInitial extends ContractSigningState {}

class ContractSigningLoading extends ContractSigningState {}

class ContractSigningOtpSent extends ContractSigningState {
  final String maXacNhan;
  final String emailMask;
  final DateTime expiredAt;

  const ContractSigningOtpSent({
    required this.maXacNhan,
    required this.emailMask,
    required this.expiredAt,
  });

  @override
  List<Object?> get props => [maXacNhan, emailMask, expiredAt];
}

class ContractSigningOtpVerifying extends ContractSigningState {
  final String maXacNhan;
  final String emailMask;
  final DateTime expiredAt;

  const ContractSigningOtpVerifying({
    required this.maXacNhan,
    required this.emailMask,
    required this.expiredAt,
  });

  @override
  List<Object?> get props => [maXacNhan, emailMask, expiredAt];
}

class ContractSigningSuccess extends ContractSigningState {
  final ContractModel updatedContract;

  const ContractSigningSuccess(this.updatedContract);

  @override
  List<Object?> get props => [updatedContract];
}

class ContractSigningFailure extends ContractSigningState {
  final String error;

  const ContractSigningFailure(this.error);

  @override
  List<Object?> get props => [error];
}
