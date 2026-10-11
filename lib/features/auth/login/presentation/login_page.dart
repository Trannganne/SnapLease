import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/widgets/app_text.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../data/auth_repository.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';
import '../../shared/widgets/auth_header_widget.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(authRepository: AuthRepository()),
      child: const LoginView(),
    );
  }
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: BlocConsumer<LoginBloc, LoginState>(
            listener: (context, state) {
              if (state.status == LoginStatus.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đăng nhập thành công')),
                );
                context.go('/');
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pageMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 40),
                    const AuthHeaderWidget(
                      badgeText: 'NỀN TẢNG THUÊ MÁY ẢNH SỐ 1',
                      badgeIcon: Icons.verified_user_outlined,
                      title: 'Chào mừng trở lại',
                      subtitle:
                          'Đăng nhập để tiếp tục thuê thiết bị cùng SNAPLEASE.',
                    ),
                    const SizedBox(height: 32),
                    // Email Field
                    AppTextField(
                      label: 'Tên đăng nhập',
                      hintText: 'Nhập tên đăng nhập',
                      controller: _emailController,
                      errorMessage: state.emailOrPhoneError,
                      prefixIcon: Icon(
                        Icons.alternate_email_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingM),
                    // Password Field
                    AppTextField(
                      label: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu',
                      controller: _passwordController,
                      isPassword: true,
                      errorMessage: state.passwordError,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      trailingLabelWidget: GestureDetector(
                        onTap: () {
                          context.push('/forgot-password');
                        },
                        child: AppText(
                          'Quên mật khẩu?',
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Ghi nhớ đăng nhập
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppText(
                          'Ghi nhớ đăng nhập',
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Đăng nhập button
                    PrimaryButton(
                      text: 'Đăng nhập',
                      isLoading: state.status == LoginStatus.loading,
                      suffixIcon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        context.read<LoginBloc>().add(
                          LoginSubmitted(
                            emailOrPhone: _emailController.text,
                            password: _passwordController.text,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 24),
                    // Divider "HOẶC"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: AppText(
                            'HOẶC',
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          // Google Login Placeholder
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.transparent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/G_logo.png', height: 24),
                            const SizedBox(width: 8),
                            Flexible(
                              child: AppText(
                                'Tiếp tục với Google',
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Footer
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppText(
                            'Chưa có tài khoản? ',
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          GestureDetector(
                            onTap: () {
                              context.push('/register');
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText(
                                  'Đăng ký',
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
