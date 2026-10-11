import 'package:equatable/equatable.dart';

enum RegisterStatus { initial, loading, success, failure }

class RegisterState extends Equatable {
  final RegisterStatus status;
  final String? usernameError;
  final String? emailError;
  final String? phoneError;
  final String? passwordError;
  final String? confirmPasswordError;
  final String? termsError;

  const RegisterState({
    this.status = RegisterStatus.initial,
    this.usernameError,
    this.emailError,
    this.phoneError,
    this.passwordError,
    this.confirmPasswordError,
    this.termsError,
  });

  RegisterState copyWith({
    RegisterStatus? status,
    String? usernameError,
    String? emailError,
    String? phoneError,
    String? passwordError,
    String? confirmPasswordError,
    String? termsError,
    bool clearErrors = false,
  }) {
    return RegisterState(
      status: status ?? this.status,
      usernameError: clearErrors ? null : (usernameError ?? this.usernameError),
      emailError: clearErrors ? null : (emailError ?? this.emailError),
      phoneError: clearErrors ? null : (phoneError ?? this.phoneError),
      passwordError: clearErrors ? null : (passwordError ?? this.passwordError),
      confirmPasswordError:
          clearErrors
              ? null
              : (confirmPasswordError ?? this.confirmPasswordError),
      termsError: clearErrors ? null : (termsError ?? this.termsError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    usernameError,
    emailError,
    phoneError,
    passwordError,
    confirmPasswordError,
    termsError,
  ];
}
