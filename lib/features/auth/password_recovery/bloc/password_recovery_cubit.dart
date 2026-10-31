import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/auth_repository.dart';
import '../../shared/auth_validation.dart';

enum PasswordRecoveryStatus {
  idle,
  loading,
  accepted,
  verificationRequested,
  emailVerified,
  loginRequired,
  resetSucceeded,
  invalidLink,
  failure,
}

class PasswordRecoveryState {
  final PasswordRecoveryStatus status;
  final String? emailError, passwordError, confirmationError, message;
  final bool uncertain;
  const PasswordRecoveryState({
    this.status = PasswordRecoveryStatus.idle,
    this.emailError,
    this.passwordError,
    this.confirmationError,
    this.message,
    this.uncertain = false,
  });
  bool get loading => status == PasswordRecoveryStatus.loading;
}

class PasswordRecoveryCubit extends Cubit<PasswordRecoveryState> {
  final AuthRepository _repository;
  String? _resetToken;
  String? _verificationToken;
  DateTime? _retryAt;
  bool _running = false;
  PasswordRecoveryCubit({
    AuthRepository? repository,
    String? resetToken,
    String? verificationToken,
  }) : _repository = repository ?? AuthRepository(),
       _resetToken = resetToken,
       _verificationToken = verificationToken,
       super(
         PasswordRecoveryState(
           status:
               (resetToken != null && resetToken.trim().isEmpty) ||
                       (verificationToken != null &&
                           verificationToken.trim().isEmpty)
                   ? PasswordRecoveryStatus.invalidLink
                   : PasswordRecoveryStatus.idle,
         ),
       );

  void clearErrors() {
    if (!_running &&
        !state.uncertain &&
        state.status != PasswordRecoveryStatus.invalidLink &&
        state.status != PasswordRecoveryStatus.resetSucceeded) {
      emit(const PasswordRecoveryState());
    }
  }

  bool _canSend() {
    if (isClosed ||
        _running ||
        state.uncertain ||
        (state.status == PasswordRecoveryStatus.resetSucceeded ||
            state.status == PasswordRecoveryStatus.emailVerified)) {
      return false;
    }
    final retryAt = _retryAt;
    if (retryAt != null && retryAt.isAfter(DateTime.now().toUtc())) {
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          message: _rateLimitMessage(retryAt),
        ),
      );
      return false;
    }
    return true;
  }

  String _rateLimitMessage(DateTime? retryAt) {
    if (retryAt == null) return 'Thao tác quá nhanh. Vui lòng chờ rồi thử lại.';
    final remaining = retryAt.difference(DateTime.now().toUtc()).inMilliseconds;
    final seconds = remaining <= 0 ? 0 : (remaining / 1000).ceil();
    return 'Thao tác quá nhanh. Vui lòng thử lại sau $seconds giây theo hướng dẫn của máy chủ.';
  }

  Future<void> requestRecovery(String email) async {
    if (!_canSend()) return;
    final error = AuthValidation.emailError(email);
    if (error != null) {
      emit(PasswordRecoveryState(emailError: error));
      return;
    }
    _running = true;
    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.loading));
    try {
      await _repository.requestPasswordRecovery(email.trim());
      if (!isClosed) {
        emit(
          const PasswordRecoveryState(status: PasswordRecoveryStatus.accepted),
        );
      }
    } catch (e) {
      if (!isClosed) _failed(e, reset: false);
    } finally {
      _running = false;
    }
  }

  Future<void> requestEmailVerification() async {
    if (!_canSend()) return;
    _running = true;
    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.loading));
    try {
      await _repository.requestEmailVerification();
      if (!isClosed) {
        emit(
          const PasswordRecoveryState(
            status: PasswordRecoveryStatus.verificationRequested,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) _failed(e, reset: false);
    } finally {
      _running = false;
    }
  }

  Future<void> verifyEmail() async {
    if (!_canSend()) return;
    final token = _verificationToken;
    if (token == null || token.isEmpty) {
      emit(
        const PasswordRecoveryState(status: PasswordRecoveryStatus.invalidLink),
      );
      return;
    }
    _running = true;
    final generation = TokenStorage.generation;
    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.loading));
    try {
      await _repository.verifyEmail(token);
      _verificationToken = null;
      if (generation == TokenStorage.generation && !TokenStorage.isChanging) {
        try {
          await TokenStorage.deleteToken();
        } catch (_) {}
      }
      if (!isClosed) {
        emit(
          const PasswordRecoveryState(
            status: PasswordRecoveryStatus.emailVerified,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) _failed(e, reset: false, verification: true);
    } finally {
      _running = false;
    }
  }

  Future<void> resetPassword(String password, String confirmation) async {
    if (!_canSend()) return;
    final token = _resetToken;
    if (token == null || token.trim().isEmpty) {
      emit(
        const PasswordRecoveryState(status: PasswordRecoveryStatus.invalidLink),
      );
      return;
    }
    final error = AuthValidation.passwordError(password);
    final confirmationError =
        confirmation.isEmpty
            ? 'Vui lòng xác nhận mật khẩu mới.'
            : confirmation != password
            ? 'Mật khẩu xác nhận không khớp.'
            : null;
    if (error != null || confirmationError != null) {
      emit(
        PasswordRecoveryState(
          passwordError: error,
          confirmationError: confirmationError,
        ),
      );
      return;
    }
    _running = true;
    final generation = TokenStorage.generation;
    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.loading));
    try {
      await _repository.resetPassword(resetToken: token, newPassword: password);
      _resetToken = null;
      // Server already succeeded. Local cleanup failure must not offer a reset retry.
      if (generation == TokenStorage.generation && !TokenStorage.isChanging) {
        try {
          await TokenStorage.deleteToken();
        } catch (_) {}
      }
      if (!isClosed) {
        emit(
          const PasswordRecoveryState(
            status: PasswordRecoveryStatus.resetSucceeded,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) _failed(e, reset: true);
    } finally {
      _running = false;
    }
  }

  void _failed(Object error, {required bool reset, bool verification = false}) {
    final failure =
        error is PasswordRecoveryFailure
            ? error
            : const PasswordRecoveryFailure(RecoveryFailureKind.unknown);
    if (failure.kind == RecoveryFailureKind.authenticationRequired) {
      emit(
        const PasswordRecoveryState(
          status: PasswordRecoveryStatus.loginRequired,
          message:
              'Vui lòng đăng nhập bằng tài khoản khách cần xác minh email.',
        ),
      );
      return;
    }
    if (failure.kind == RecoveryFailureKind.invalidLink) {
      _resetToken = null;
      _verificationToken = null;
      emit(
        const PasswordRecoveryState(status: PasswordRecoveryStatus.invalidLink),
      );
      return;
    }
    _retryAt = failure.retryAt;
    final message = switch (failure.kind) {
      RecoveryFailureKind.emailRequired =>
        'Tài khoản chưa có email. Vui lòng bổ sung email trước khi yêu cầu xác minh.',
      RecoveryFailureKind.emailConflict =>
        'Email đã được xác minh cho tài khoản khác. Vui lòng kiểm tra lại tài khoản và email của bạn.',
      RecoveryFailureKind.authenticationRequired =>
        'Vui lòng đăng nhập bằng tài khoản khách cần xác minh email.',
      RecoveryFailureKind.rateLimited => _rateLimitMessage(failure.retryAt),
      RecoveryFailureKind.validation =>
        reset
            ? 'Mật khẩu chưa đáp ứng yêu cầu. Vui lòng kiểm tra lại.'
            : 'Vui lòng kiểm tra lại địa chỉ email.',
      RecoveryFailureKind.network =>
        verification
            ? 'Chưa xác định kết quả xác minh email. Vui lòng đăng nhập lại hoặc yêu cầu liên kết mới.'
            : reset
            ? 'Chưa xác định được kết quả cập nhật. Hãy thử đăng nhập bằng mật khẩu mới; nếu không được, yêu cầu liên kết mới.'
            : 'Không thể kết nối máy chủ. Vui lòng kiểm tra đường truyền và thử lại.',
      _ =>
        (reset || verification) && failure.uncertain
            ? 'Chưa xác định được kết quả cập nhật. Hãy kiểm tra bằng cách đăng nhập hoặc yêu cầu liên kết mới.'
            : 'Chưa thể xử lý yêu cầu. Vui lòng thử lại sau.',
    };
    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.failure,
        message: message,
        uncertain: (reset || verification) && failure.uncertain,
        emailError:
            !reset && failure.kind == RecoveryFailureKind.validation
                ? message
                : null,
        passwordError:
            reset && failure.kind == RecoveryFailureKind.validation
                ? message
                : null,
      ),
    );
  }

  @override
  Future<void> close() {
    _resetToken = null;
    _verificationToken = null;
    return super.close();
  }
}
