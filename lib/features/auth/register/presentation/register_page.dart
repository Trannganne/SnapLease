import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import 'package:flutter/gestures.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/auth_repository.dart';
import '../../shared/widgets/auth_header_widget.dart';
import '../bloc/register_bloc.dart';
import '../bloc/register_event.dart';
import '../bloc/register_state.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegisterBloc(authRepository: AuthRepository()),
      child: const RegisterView(),
    );
  }
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isTermsAccepted = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(248, 249, 255, 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    context.go('/login');
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: Color(0xFF121C2A),
                    ),
                  ),
                ),
                const Expanded(
                  child: AppText(
                    'Đăng Ký',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF121C2A),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 44), // To balance the title
              ],
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: BlocConsumer<RegisterBloc, RegisterState>(
            listener: (context, state) {
              if (state.status == RegisterStatus.success) {
                context.go('/login');
              }
              if (state.termsError != null && state.termsError!.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.termsError!),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pageMargin,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 32),
                    const AuthHeaderWidget(
                      badgeText: 'CỘNG ĐỒNG SÁNG TẠO',
                      badgeIcon: Icons.camera_enhance_outlined,
                      title: 'Tạo tài khoản',
                      subtitle:
                          'Đăng ký để bắt đầu trải nghiệm thuê thiết bị cùng\nSNAPLEASE.',
                      badgeBgColor: Color(0xFFE6EEFF),
                      badgeTextColor: Color(0xFF00219F),
                    ),
                    const SizedBox(height: 32),

                    // Form fields
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên đăng nhập
                        AppTextField(
                          label: 'Tên đăng nhập',
                          isRequired: true,
                          hintText: 'Nhập tên đăng nhập',
                          controller: _usernameController,
                          errorMessage: state.usernameError,
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Email
                        AppTextField(
                          label: 'Email',
                          isRequired: true,
                          hintText: 'Nhập địa chỉ email',
                          controller: _emailController,
                          errorMessage: state.emailError,
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Số điện thoại
                        AppTextField(
                          label: 'Số điện thoại',
                          isRequired: true,
                          hintText: 'Nhập số điện thoại',
                          controller: _phoneController,
                          errorMessage: state.phoneError,
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Mật khẩu
                        AppTextField(
                          label: 'Mật khẩu',
                          isRequired: true,
                          hintText: 'Tạo mật khẩu',
                          controller: _passwordController,
                          isPassword: true,
                          errorMessage: state.passwordError,
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFF444654),
                              ),
                              const SizedBox(width: 4),
                              const AppText(
                                'Mật khẩu từ 8–128 ký tự, gồm chữ hoa, thường, số và ký tự đặc biệt.',
                                fontSize: 11,
                                color: Color(0xFF444654),
                              ),
                            ],
                          ),
                        ),
                        // Nhập lại mật khẩu
                        AppTextField(
                          label: 'Nhập lại mật khẩu',
                          isRequired: true,
                          hintText: 'Nhập lại mật khẩu',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          errorMessage: state.confirmPasswordError,
                          prefixIcon: Icon(
                            Icons.lock_reset_outlined,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _isTermsAccepted,
                            onChanged: (value) {
                              setState(() {
                                _isTermsAccepted = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF1D39C4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12,
                                height:
                                    1.4, // approximately 16-17px line height
                                color: Color(0xFF121C2A),
                                fontFamily: 'Roboto',
                              ),
                              children: [
                                const TextSpan(text: 'Tôi đồng ý với '),
                                TextSpan(
                                  text: 'Điều khoản sử dụng',
                                  style: const TextStyle(
                                    color: Color(0xFF1D39C4),
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          // TODO: Open terms
                                        },
                                ),
                                const TextSpan(text: ' và '),
                                TextSpan(
                                  text: 'Chính sách bảo mật',
                                  style: const TextStyle(
                                    color: Color(0xFF1D39C4),
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  recognizer:
                                      TapGestureRecognizer()
                                        ..onTap = () {
                                          // TODO: Open privacy policy
                                        },
                                ),
                                const TextSpan(text: ' của SNAPLEASE.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.buttonHeight,
                      child: ElevatedButton(
                        onPressed:
                            state.status == RegisterStatus.loading
                                ? null
                                : () {
                                  context.read<RegisterBloc>().add(
                                    RegisterSubmitted(
                                      username: _usernameController.text,
                                      email: _emailController.text,
                                      phone: _phoneController.text,
                                      password: _passwordController.text,
                                      confirmPassword:
                                          _confirmPasswordController.text,
                                      isTermsAccepted: _isTermsAccepted,
                                    ),
                                  );
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D39C4),
                          disabledBackgroundColor: const Color(
                            0xFF1D39C4,
                          ).withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        child:
                            state.status == RegisterStatus.loading
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AppText(
                                      'Đăng ký',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppText(
                          'Đã có tài khoản?',
                          color: Color(0xFF444654),
                          fontSize: 14,
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            context.go('/login');
                          },
                          child: const AppText(
                            'Đăng nhập',
                            color: Color(0xFF1D39C4),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Info Row
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: Color(0xFF444654),
                        ),
                        SizedBox(width: 4),
                        AppText(
                          'Bảo mật 100%',
                          color: Color(0xFF444654),
                          fontSize: 11,
                        ),
                        SizedBox(width: 8),
                        AppText('•', color: Color(0xFF444654), fontSize: 11),
                        SizedBox(width: 8),
                        Icon(
                          Icons.speed_outlined,
                          size: 14,
                          color: Color(0xFF444654),
                        ),
                        SizedBox(width: 4),
                        AppText(
                          'Xác thực nhanh',
                          color: Color(0xFF444654),
                          fontSize: 11,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
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
