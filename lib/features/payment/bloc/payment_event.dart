import 'package:equatable/equatable.dart';
import '../domain/enums/payment_method.dart';

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentStatus extends PaymentEvent {
  final String contractId;

  const LoadPaymentStatus(this.contractId);

  @override
  List<Object?> get props => [contractId];
}

class CreatePaymentRequested extends PaymentEvent {
  final String contractId;
  final PaymentMethod method;

  const CreatePaymentRequested(this.contractId, this.method);

  @override
  List<Object?> get props => [contractId, method];
}
