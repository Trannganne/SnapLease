import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_repository.dart';
import 'register_event.dart';
import 'register_state.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final AuthRepository authRepository;

  RegisterBloc({required this.authRepository}) : super(const RegisterState()) {
    on<RegisterSubmitted>(_onRegisterSubmitted);
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    String? usernameError;
    String? emailError;
    String? phoneError;
    String? passwordError;
    String? confirmPasswordError;
    String? termsError;

    if (event.username.isEmpty) {
      usernameError = 'Vui lòng nhập tên đăng nhập';
    } else if (event.username.length < 4 || event.username.length > 50) {
      usernameError = 'Tên đăng nhập từ 4 đến 50 ký tự';
    }

    if (event.email.isEmpty) {
      emailError = 'Vui lòng nhập email';
    }

    if (event.phone.isEmpty) {
      phoneError = 'Vui lòng nhập số điện thoại';
    }

    if (event.password.isEmpty) {
      passwordError = 'Vui lòng nhập mật khẩu';
    } else if (event.password.length < 8 || event.password.length > 128) {
      passwordError = 'Mật khẩu từ 8 đến 128 ký tự';
    } else {
      final hasUpper = RegExp(r'\p{Lu}', unicode: true).hasMatch(event.password);
      final hasLower = RegExp(r'\p{Ll}', unicode: true).hasMatch(event.password);
      final hasDigit = RegExp(r'\p{Nd}', unicode: true).hasMatch(event.password);
      final hasSpecial = RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true).hasMatch(event.password);

      if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
        passwordError = 'Mật khẩu phải gồm chữ hoa, thường, số và ký tự đặc biệt';
      }
    }

    if (event.confirmPassword.isEmpty) {
      confirmPasswordError = 'Vui lòng nhập lại mật khẩu';
    } else if (event.confirmPassword != event.password) {
      confirmPasswordError = 'Mật khẩu nhập lại không khớp';
    }

    if (!event.isTermsAccepted) {
      termsError = 'Bạn phải đồng ý với điều khoản';
    }

    if (usernameError != null ||
        emailError != null ||
        phoneError != null ||
        passwordError != null ||
        confirmPasswordError != null ||
        termsError != null) {
      emit(
        RegisterState(
          status: RegisterStatus.initial,
          usernameError: usernameError,
          emailError: emailError,
          phoneError: phoneError,
          passwordError: passwordError,
          confirmPasswordError: confirmPasswordError,
          termsError: termsError,
        ),
      );
      return;
    }

    emit(state.copyWith(status: RegisterStatus.loading, clearErrors: true));

    try {
      await authRepository.register(
        event.username,
        event.email,
        event.phone,
        event.password,
      );
      emit(state.copyWith(status: RegisterStatus.success));
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      
      // We can map the message to the termsError for general display since the backend returns a single "loi" string,
      // or we can just pass it to one of the fields. Let's use termsError as a general error displaying snakbar
      termsError = message;

      emit(
        RegisterState(
          status: RegisterStatus.failure,
          termsError: termsError,
        ),
      );
    }
  }
}
