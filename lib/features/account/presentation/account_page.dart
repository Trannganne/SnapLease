import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../rental/bloc/rental_bloc.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Image.asset('assets/images/logo.png', height: 24),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onSurface),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined, color: colorScheme.onSurface),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            AppText(
              'Tài khoản',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            AppText(
              'Quản lý hồ sơ & thiết bị SNAPLEASE',
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            _buildProfileCard(context),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'HOẠT ĐỘNG CỦA TÔI'),
            _buildMenuCard(context, [
              _buildMenuItem(context, Icons.receipt_long, 'Đơn thuê của tôi', 'Xem hợp đồng & lịch nhận trả thiết bị'),
              _buildMenuItem(context, Icons.favorite_border, 'Yêu thích', 'Thiết bị & combo ống kính đã lưu'),
              _buildMenuItem(context, Icons.account_balance_wallet_outlined, 'Lịch sử thanh toán & cọc', 'Hoàn cọc, hóa đơn VAT điện tử'),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'GIAO DIỆN & HỆ THỐNG'),
            _buildThemeSelector(context),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'THIẾT LẬP TÀI KHOẢN'),
            _buildMenuCard(context, [
              _buildMenuItem(context, Icons.person_outline, 'Thông tin cá nhân & Giấy tờ'),
              _buildMenuItem(context, Icons.location_on_outlined, 'Địa chỉ nhận thiết bị'),
              _buildMenuItem(context, Icons.credit_card_outlined, 'Phương thức thanh toán'),
              _buildMenuItem(context, Icons.security_outlined, 'Bảo mật & Mật khẩu'),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'HỖ TRỢ & PHÁP LÝ'),
            _buildMenuCard(context, [
              _buildMenuItem(context, Icons.headset_mic_outlined, 'Hỗ trợ kỹ thuật 24/7'),
              _buildMenuItem(context, Icons.help_outline, 'Câu hỏi thường gặp (FAQ)'),
              _buildMenuItem(context, Icons.camera_alt_outlined, 'SNAPLEASE Creator App'),
            ]),
            const SizedBox(height: 24),
            _buildLogoutButton(context),
            const SizedBox(height: 32),
            Center(
              child: AppText(
                'SNAPLEASE v1.0.0',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const UserAvatar(
            radius: 30,
            displayName: '?', // Trạng thái chưa có dữ liệu
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Chưa cập nhật tên',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(height: 4),
                AppText(
                  'Chưa cập nhật email',
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    AppText(
                      'Chưa xác minh CCCD',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: AppText(
        title,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, List<Widget> items) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          if (index == items.length - 1) {
            return item;
          }
          return Column(
            children: [
              item,
              Divider(
                height: 1,
                thickness: 1,
                indent: 56,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, [String? subtitle]) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: colorScheme.onSurface),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    title,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, currentMode) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildThemeOption(
                context,
                icon: Icons.light_mode_outlined,
                label: 'Sáng',
                isSelected: currentMode == ThemeMode.light,
                onTap: () => context.read<ThemeCubit>().updateThemeMode(ThemeMode.light),
              ),
              _buildThemeOption(
                context,
                icon: Icons.dark_mode_outlined,
                label: 'Tối',
                isSelected: currentMode == ThemeMode.dark,
                onTap: () => context.read<ThemeCubit>().updateThemeMode(ThemeMode.dark),
              ),
              _buildThemeOption(
                context,
                icon: Icons.settings_outlined,
                label: 'Hệ thống',
                isSelected: currentMode == ThemeMode.system,
                onTap: () => context.read<ThemeCubit>().updateThemeMode(ThemeMode.system),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              AppText(
                label,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        _showLogoutDialog(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            AppText(
              'Đăng xuất tài khoản',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout,
                      color: colorScheme.error,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppText(
                    'Đăng xuất',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
                    fontSize: 14,
                    textAlign: TextAlign.center,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isProcessing
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop();
                                },
                          style: TextButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AppText(
                            'Hủy bỏ',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setState(() {
                                    isProcessing = true;
                                  });
                                  context.read<RentalBloc>().add(const ClearRentalState());
                                  await TokenStorage.deleteToken();
                                  if (dialogContext.mounted) {
                                    dialogContext.go('/login');
                                  }
                                },
                          style: TextButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AppText(
                            'Đăng xuất',
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
