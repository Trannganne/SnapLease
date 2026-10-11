import 'package:equatable/equatable.dart';

enum LoginStatus { initial, loading, success, failure }

class LoginState extends Equatable {
  final LoginStatus status;
  final String? emailOrPhoneError;
  final String? passwordError;

  const LoginState({
    this.status = LoginStatus.initial,
    this.emailOrPhoneError,
    this.passwordError,
  });

  LoginState copyWith({
    LoginStatus? status,
    String? emailOrPhoneError,
    String? passwordError,
    bool clearErrors = false,
  }) {
    return LoginState(
      status: status ?? this.status,
      emailOrPhoneError:
          clearErrors ? null : (emailOrPhoneError ?? this.emailOrPhoneError),
      passwordError: clearErrors ? null : (passwordError ?? this.passwordError),
    );
  }

  @override
  List<Object?> get props => [status, emailOrPhoneError, passwordError];
}
