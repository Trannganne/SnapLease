import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/auth_repository.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository authRepository;

  LoginBloc({required this.authRepository}) : super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    // 1. Local validation
    String? emailError;
    String? passwordError;

    if (event.emailOrPhone.trim().isEmpty) {
      emailError = 'Vui lòng nhập tên đăng nhập';
    }
    if (event.password.isEmpty) {
      passwordError = 'Vui lòng nhập mật khẩu';
    }

    if (emailError != null || passwordError != null) {
      emit(
        LoginState(
          status: LoginStatus.initial,
          emailOrPhoneError: emailError,
          passwordError: passwordError,
        ),
      );
      return;
    }

    // Clear previous errors and set loading
    emit(const LoginState(status: LoginStatus.loading));

    try {
      final responseData = await authRepository.login(
        event.emailOrPhone,
        event.password,
      );

      final token = responseData['accessToken'];
      if (token != null) {
        await TokenStorage.saveToken(
          token,
          accountId: responseData['maTaiKhoan'] as String?,
        );
      }

      emit(const LoginState(status: LoginStatus.success));
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');

      if (errorMsg.contains('mật khẩu') || errorMsg.contains('tài khoản')) {
        emit(LoginState(status: LoginStatus.failure, passwordError: errorMsg));
      } else if (errorMsg.contains('kết nối')) {
        emit(
          LoginState(status: LoginStatus.failure, emailOrPhoneError: errorMsg),
        );
      } else {
        emit(
          LoginState(status: LoginStatus.failure, emailOrPhoneError: errorMsg),
        );
      }
    }
  }
}
