import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_notice_dialog.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/auth_repository.dart';
import '../../shared/auth_validation.dart';
import '../../shared/widgets/auth_header_widget.dart';
import '../bloc/password_recovery_cubit.dart';

// Token arguments stay in memory; the router validates approved Android links.
class PasswordResetArguments {
  final String resetToken;
  const PasswordResetArguments(this.resetToken);
}

class EmailVerificationArguments {
  final String? token;
  final bool requestLink;
  const EmailVerificationArguments.request() : token = null, requestLink = true;
  const EmailVerificationArguments.token(this.token) : requestLink = false;
}

class ForgotPasswordPage extends StatelessWidget {
  final AuthRepository? repository;
  const ForgotPasswordPage({super.key, this.repository});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PasswordRecoveryCubit(repository: repository),
    child: const _PasswordRecoveryView(reset: false),
  );
}

class ResetPasswordPage extends StatefulWidget {
  final String? resetToken;
  final AuthRepository? repository;
  final bool emailVerification;
  final bool requestVerification;
  const ResetPasswordPage({
    super.key,
    this.resetToken,
    this.repository,
    this.emailVerification = false,
    this.requestVerification = false,
  });
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late PasswordRecoveryCubit _cubit;
  int _generation = 0;
  PasswordRecoveryCubit _createCubit() => PasswordRecoveryCubit(
    repository: widget.repository,
    resetToken: widget.emailVerification ? null : widget.resetToken ?? '',
    verificationToken:
        widget.emailVerification && !widget.requestVerification
            ? widget.resetToken ?? ''
            : null,
  );
  @override
  void initState() {
    super.initState();
    _cubit = _createCubit();
  }

  @override
  void didUpdateWidget(ResetPasswordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken ||
        oldWidget.repository != widget.repository ||
        oldWidget.emailVerification != widget.emailVerification ||
        oldWidget.requestVerification != widget.requestVerification) {
      _cubit.close();
      _cubit = _createCubit();
      _generation++;
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: _PasswordRecoveryView(
      key: ValueKey(_generation),
      reset: true,
      emailVerification: widget.emailVerification,
      requestVerification: widget.requestVerification,
    ),
  );
}

class _PasswordRecoveryView extends StatefulWidget {
  final bool reset;
  final bool emailVerification;
  final bool requestVerification;
  const _PasswordRecoveryView({
    super.key,
    required this.reset,
    this.emailVerification = false,
    this.requestVerification = false,
  });
  @override
  State<_PasswordRecoveryView> createState() => _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends State<_PasswordRecoveryView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _email.clear();
    _password.clear();
    _confirmation.clear();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    final cubit = context.read<PasswordRecoveryCubit>();
    if (widget.emailVerification) {
      if (widget.requestVerification) {
        cubit.requestEmailVerification();
      } else {
        cubit.verifyEmail();
      }
    } else if (widget.reset) {
      cubit.resetPassword(_password.text, _confirmation.text);
    } else {
      cubit.requestRecovery(_email.text);
    }
  }

  Future<void> _onState(
    BuildContext context,
    PasswordRecoveryState state,
  ) async {
    if (state.status == PasswordRecoveryStatus.loginRequired) {
      await showAppNoticeDialog(
        context,
        title: 'Cần đăng nhập',
        message: state.message ?? '',
        action: 'Quay lại đăng nhập',
      );
      if (context.mounted) context.go(AppRouter.login);
      return;
    }
    if (state.status == PasswordRecoveryStatus.verificationRequested) {
      await showAppNoticeDialog(
        context,
        title: 'Kiểm tra hộp thư của bạn',
        message:
            'Yêu cầu đã được tiếp nhận. Nếu email của bạn cần xác minh, hãy mở liên kết trong email để tiếp tục. Vui lòng kiểm tra cả thư mục Spam.',
        action: 'Đóng',
        icon: Icons.mark_email_read_outlined,
      );
      return;
    }
    if (state.status == PasswordRecoveryStatus.emailVerified) {
      await showAppNoticeDialog(
        context,
        title: 'Email đã được xác minh',
        message: 'Vui lòng đăng nhập lại để tiếp tục sử dụng tài khoản.',
        action: 'Quay lại đăng nhập',
        icon: Icons.check_circle_outline,
      );
      if (context.mounted) context.go(AppRouter.login);
      return;
    }
    if (state.status == PasswordRecoveryStatus.accepted) {
      final login = await showAppNoticeDialog(
        context,
        title: 'Kiểm tra hộp thư của bạn',
        message:
            'Nếu email phù hợp với tài khoản đủ điều kiện, bạn sẽ nhận được liên kết đặt lại mật khẩu. Vui lòng kiểm tra cả thư mục Spam.',
        action: 'Quay lại đăng nhập',
        secondaryAction: 'Đóng',
        icon: Icons.check_circle_outline,
      );
      if (login == true && context.mounted) context.go(AppRouter.login);
    } else if (state.status == PasswordRecoveryStatus.resetSucceeded) {
      _password.clear();
      _confirmation.clear();
      _email.clear();
      await showAppNoticeDialog(
        context,
        title: 'Đặt lại mật khẩu thành công',
        message:
            'Bạn có thể đăng nhập bằng mật khẩu mới. Các phiên đăng nhập cũ đã mất hiệu lực.',
        action: 'Quay lại đăng nhập',
        icon: Icons.check_circle_outline,
      );
      if (context.mounted) context.go(AppRouter.login);
    } else if (state.status == PasswordRecoveryStatus.failure &&
        (widget.emailVerification ||
            (state.emailError == null && state.passwordError == null))) {
      final result = await showAppNoticeDialog(
        context,
        title:
            state.uncertain ? 'Cần kiểm tra kết quả' : 'Chưa thể gửi yêu cầu',
        message: state.message ?? 'Vui lòng thử lại sau.',
        action: state.uncertain ? 'Quay lại đăng nhập' : 'Thử lại',
        secondaryAction: state.uncertain ? 'Yêu cầu liên kết mới' : 'Hủy bỏ',
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
      );
      if (!context.mounted || result == null) return;
      if (state.uncertain) {
        if (widget.emailVerification && !result) {
          context.go(
            AppRouter.verifyEmail,
            extra: const EmailVerificationArguments.request(),
          );
        } else {
          context.go(result ? AppRouter.login : AppRouter.forgotPassword);
        }
      } else if (result) {
        _submit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.emailVerification) return _emailVerification(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.reset ? 'Đặt lại mật khẩu' : 'Quên mật khẩu'),
        leading: IconButton(
          tooltip: 'Quay lại đăng nhập',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRouter.login),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
          listener: _onState,
          builder:
              (context, state) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.pageMargin),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AutofillGroup(
                      onDisposeAction: AutofillContextAction.cancel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          AuthHeaderWidget(
                            prominentIcon: true,
                            badgeText: '',
                            badgeIcon:
                                widget.reset
                                    ? Icons.lock_outline
                                    : Icons.mark_email_unread_outlined,
                            title:
                                widget.reset
                                    ? 'Tạo mật khẩu mới'
                                    : 'Quên mật khẩu?',
                            subtitle:
                                widget.reset
                                    ? 'Hãy tạo mật khẩu mới để tiếp tục trải nghiệm thuê thiết bị tại SNAPLEASE.'
                                    : 'Nhập email đã đăng ký và đã xác minh để nhận hướng dẫn khôi phục tài khoản SNAPLEASE.',
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: .3,
                                ),
                              ),
                            ),
                            child:
                                state.status ==
                                        PasswordRecoveryStatus.invalidLink
                                    ? Column(
                                      children: [
                                        Icon(
                                          Icons.link_off,
                                          color: colors.error,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 12),
                                        const AppText(
                                          'Liên kết không hợp lệ hoặc đã hết hạn',
                                          fontWeight: FontWeight.bold,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        const AppText(
                                          'Liên kết có thể đã được sử dụng hoặc không còn hiệu lực. Vui lòng yêu cầu liên kết mới.',
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        PrimaryButton(
                                          text: 'Yêu cầu liên kết mới',
                                          onPressed:
                                              () => context.go(
                                                AppRouter.forgotPassword,
                                              ),
                                        ),
                                        _loginLink(context),
                                      ],
                                    )
                                    : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!widget.reset) ...[
                                          AppTextField(
                                            label: 'Email đã đăng ký',
                                            hintText: 'example@email.com',
                                            controller: _email,
                                            errorMessage: state.emailError,
                                            enabled: !state.loading,
                                            adaptiveHeight: true,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.email,
                                            ],
                                            onSubmitted: (_) => _submit(),
                                            onChanged:
                                                (_) =>
                                                    context
                                                        .read<
                                                          PasswordRecoveryCubit
                                                        >()
                                                        .clearErrors(),
                                            prefixIcon: const Icon(
                                              Icons.mail_outline,
                                            ),
                                            trailingLabelWidget: AppText(
                                              'Yêu cầu xác minh',
                                              fontSize: 10,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          AppText(
                                            'Chúng tôi sẽ gửi liên kết bảo mật về hộp thư của bạn nếu tài khoản đủ điều kiện.',
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ] else ...[
                                          AppTextField(
                                            label: 'Mật khẩu mới',
                                            hintText: 'Nhập mật khẩu mới',
                                            controller: _password,
                                            isPassword: true,
                                            errorMessage: state.passwordError,
                                            enabled:
                                                !state.loading &&
                                                !state.uncertain,
                                            adaptiveHeight: true,
                                            textInputAction:
                                                TextInputAction.next,
                                            autofillHints: const [
                                              AutofillHints.newPassword,
                                            ],
                                            onChanged:
                                                (_) =>
                                                    context
                                                        .read<
                                                          PasswordRecoveryCubit
                                                        >()
                                                        .clearErrors(),
                                            prefixIcon: const Icon(
                                              Icons.lock_outline,
                                            ),
                                            isRequired: true,
                                          ),
                                          const SizedBox(height: 8),
                                          AppText(
                                            AuthValidation.passwordRule,
                                            fontSize: 12,
                                            color: colors.onSurfaceVariant,
                                          ),
                                          const SizedBox(height: 20),
                                          AppTextField(
                                            label: 'Xác nhận mật khẩu mới',
                                            hintText: 'Nhập lại mật khẩu mới',
                                            controller: _confirmation,
                                            isPassword: true,
                                            errorMessage:
                                                state.confirmationError,
                                            enabled:
                                                !state.loading &&
                                                !state.uncertain,
                                            adaptiveHeight: true,
                                            textInputAction:
                                                TextInputAction.done,
                                            onSubmitted: (_) => _submit(),
                                            autofillHints: const [
                                              AutofillHints.newPassword,
                                            ],
                                            onChanged:
                                                (_) =>
                                                    context
                                                        .read<
                                                          PasswordRecoveryCubit
                                                        >()
                                                        .clearErrors(),
                                            prefixIcon: const Icon(
                                              Icons.lock_outline,
                                            ),
                                            isRequired: true,
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        if (state.uncertain) ...[
                                          AppText(
                                            state.message ?? '',
                                            color: colors.error,
                                          ),
                                          const SizedBox(height: 12),
                                          PrimaryButton(
                                            text: 'Yêu cầu liên kết mới',
                                            onPressed:
                                                () => context.go(
                                                  AppRouter.forgotPassword,
                                                ),
                                          ),
                                        ] else
                                          PrimaryButton(
                                            text:
                                                state.loading
                                                    ? 'Đang xử lý yêu cầu…'
                                                    : widget.reset
                                                    ? 'Cập nhật mật khẩu'
                                                    : 'Gửi yêu cầu khôi phục',
                                            isLoading: state.loading,
                                            onPressed:
                                                state.status ==
                                                        PasswordRecoveryStatus
                                                            .resetSucceeded
                                                    ? null
                                                    : _submit,
                                          ),
                                        _loginLink(context),
                                      ],
                                    ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  widget.reset
                                      ? Icons.shield_outlined
                                      : Icons.history,
                                  color: colors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.reset) ...[
                                        AppText(
                                          'Bảo mật thiết bị & đơn thuê',
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                      AppText(
                                        widget.reset
                                            ? 'Sau khi đặt lại mật khẩu thành công, các phiên đăng nhập cũ sẽ mất hiệu lực. Bạn cần đăng nhập lại để tiếp tục quản lý hợp đồng.'
                                            : 'Để bảo vệ tài khoản, hệ thống không xác nhận công khai email có trong cơ sở dữ liệu hay không.',
                                        fontSize: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _emailVerification(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Xác minh email'),
      leading: IconButton(
        tooltip: 'Quay lại đăng nhập',
        onPressed: () => context.go(AppRouter.login),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
        listener: _onState,
        builder:
            (context, current) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.pageMargin),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      AuthHeaderWidget(
                        prominentIcon: true,
                        badgeText: '',
                        badgeIcon: Icons.verified_user_outlined,
                        title: 'Xác minh email',
                        subtitle:
                            widget.requestVerification
                                ? 'Gửi liên kết đến email trong hồ sơ tài khoản khách đang đăng nhập.'
                                : 'Chỉ tiếp tục nếu bạn đã yêu cầu xác minh email và nhận được liên kết này.',
                      ),
                      const SizedBox(height: 24),
                      if (current.status ==
                              PasswordRecoveryStatus.invalidLink ||
                          current.uncertain) ...[
                        AppText(
                          current.uncertain
                              ? current.message ??
                                  'Chưa xác định được kết quả xác minh.'
                              : 'Liên kết không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập và yêu cầu liên kết mới.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          text: 'Yêu cầu liên kết mới',
                          onPressed:
                              () => context.go(
                                AppRouter.verifyEmail,
                                extra:
                                    const EmailVerificationArguments.request(),
                              ),
                        ),
                      ] else
                        PrimaryButton(
                          text:
                              widget.requestVerification
                                  ? 'Gửi liên kết xác minh'
                                  : 'Xác minh email',
                          isLoading: current.loading,
                          onPressed:
                              current.status ==
                                      PasswordRecoveryStatus.emailVerified
                                  ? null
                                  : _submit,
                        ),
                      const SizedBox(height: 12),
                      const AppText(
                        'Mở màn hình này không tự gửi email hoặc xác minh. Chỉ xác nhận nếu liên kết thuộc yêu cầu của bạn.',
                        fontSize: 12,
                        textAlign: TextAlign.center,
                      ),
                      _loginLink(context),
                    ],
                  ),
                ),
              ),
            ),
      ),
    ),
  );

  Widget _loginLink(BuildContext context) => TextButton.icon(
    onPressed: () => context.go(AppRouter.login),
    icon: const Icon(Icons.arrow_back, size: 18),
    label: const Text('Quay lại đăng nhập'),
  );
}
