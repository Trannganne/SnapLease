import 'package:equatable/equatable.dart';
import '../domain/models/payment_model.dart';

abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {}

class PaymentLoaded extends PaymentState {
  final PaymentModel? activePayment;

  const PaymentLoaded(this.activePayment);

  @override
  List<Object?> get props => [activePayment];
}

class PaymentCreating extends PaymentState {}

class PaymentCreateSuccess extends PaymentState {
  final PaymentModel payment;

  const PaymentCreateSuccess(this.payment);

  @override
  List<Object?> get props => [payment];
}

class PaymentCreatePending extends PaymentState {
  final PaymentModel payment;

  const PaymentCreatePending(this.payment);

  @override
  List<Object?> get props => [payment];
}

class PaymentError extends PaymentState {
  final String message;

  const PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}
