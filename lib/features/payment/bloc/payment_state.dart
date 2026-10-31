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

class PaymentOpenUrl extends PaymentState {
  final String url;
  final PaymentModel payment;

  const PaymentOpenUrl({required this.url, required this.payment});

  @override
  List<Object?> get props => [url, payment];
}

class PaymentChecking extends PaymentState {
  final PaymentModel? currentPayment;

  const PaymentChecking({this.currentPayment});

  @override
  List<Object?> get props => [currentPayment];
}

class PaymentStatusChecked extends PaymentState {
  final PaymentModel payment;
  final String message;
  final bool isStillPending;

  const PaymentStatusChecked({
    required this.payment,
    required this.message,
    required this.isStillPending,
  });

  @override
  List<Object?> get props => [payment, message, isStillPending];
}

class PaymentError extends PaymentState {
  final String message;

  const PaymentError(this.message);

  @override
  List<Object?> get props => [message];
}
