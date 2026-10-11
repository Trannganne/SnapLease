import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../bloc/identity_verification_bloc.dart';
import '../../bloc/identity_verification_event.dart';
import '../../bloc/identity_verification_state.dart';
import '../../services/identity_scanner.dart';

class VerificationResultReview extends StatelessWidget {
  final ExtractedIdentityData data;

  const VerificationResultReview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const AppText(
          'Xác nhận thông tin',
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        const SizedBox(height: 8),
        AppText(
          'Vui lòng kiểm tra lại các thông tin được trích xuất từ ảnh chụp.',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        const SizedBox(height: 24),
        _buildField(context, 'Số CCCD', data.cccd),
        _buildField(context, 'Họ tên', data.hoTen),
        _buildField(context, 'Ngày sinh', data.ngaySinh),
        _buildField(context, 'Giới tính', data.gioiTinh),
        _buildField(context, 'Quốc tịch', data.quocTich),
        _buildField(context, 'Địa chỉ thường trú', data.diaChiThuongTru),
        _buildField(context, 'Ngày cấp', data.ngayCap),
        _buildField(context, 'Nơi cấp', data.noiCap),
        const SizedBox(height: 40),
        BlocBuilder<IdentityVerificationBloc, IdentityVerificationState>(
          builder: (context, state) {
            final isLoading = state.status == IdentityVerificationStatus.confirming;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  text: 'Xác nhận và tiếp tục',
                  onPressed: data.isValid && !isLoading
                      ? () => context.read<IdentityVerificationBloc>().add(ConfirmVerification())
                      : null,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          context.read<IdentityVerificationBloc>()
                            ..add(RemoveFrontImage())
                            ..add(RemoveBackImage());
                        },
                  child: AppText('Chụp lại CCCD', color: Theme.of(context).colorScheme.primary),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, String label, IdentityField? field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppText(
                label,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              if (field != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AppText(
                    field.source,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            field?.value ?? 'Không đọc được',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: field == null ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}
