import 'package:equatable/equatable.dart';

abstract class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  final String username;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;
  final bool isTermsAccepted;

  const RegisterSubmitted({
    required this.username,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmPassword,
    required this.isTermsAccepted,
  });

  @override
  List<Object?> get props => [
    username,
    email,
    phone,
    password,
    confirmPassword,
    isTermsAccepted,
  ];
}
