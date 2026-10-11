import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/contract_signing_cubit.dart';
import '../bloc/contract_signing_state.dart';
import '../../services/contract_pdf_service.dart';

class OtpVerificationDialog extends StatefulWidget {
  final ContractModel contract;
  final String maXacNhan;
  final String emailMask;
  final DateTime expiredAt;
  final bool daDongYDieuKhoan;

  const OtpVerificationDialog({
    super.key,
    required this.contract,
    required this.maXacNhan,
    required this.emailMask,
    required this.expiredAt,
    required this.daDongYDieuKhoan,
  });

  @override
  State<OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<OtpVerificationDialog> {
  String _otp = "";
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _updateRemainingSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateRemainingSeconds();
        });
      }
    });
  }

  void _updateRemainingSeconds() {
    final diff = widget.expiredAt.difference(DateTime.now()).inSeconds;
    _remainingSeconds = diff > 0 ? diff : 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const AppText(
              'Xác nhận mã OTP',
              textAlign: TextAlign.center,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            AppText(
              'Mã xác nhận gồm 6 chữ số đã được gửi đến email:\n${widget.emailMask}',
              textAlign: TextAlign.center,
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            const SizedBox(height: 24),
            TextField(
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                counterText: "",
              ),
              onChanged: (value) {
                setState(() {
                  _otp = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_remainingSeconds > 0)
              AppText(
                'Mã hết hạn sau: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                color: AppColors.error,
                fontSize: 14,
              )
            else
              const AppText(
                'Mã đã hết hạn, vui lòng yêu cầu gửi lại.',
                textAlign: TextAlign.center,
                color: AppColors.error,
                fontSize: 14,
              ),
            const SizedBox(height: 24),
            BlocBuilder<ContractSigningCubit, ContractSigningState>(
              builder: (context, state) {
                final isVerifying = state is ContractSigningOtpVerifying;
                return PrimaryButton(
                  text: 'Xác nhận',
                  isLoading: isVerifying,
                  onPressed: _otp.length == 6 && _remainingSeconds > 0
                      ? () {
                          context.read<ContractSigningCubit>().verifyOtp(
                                widget.contract,
                                widget.maXacNhan,
                                _otp,
                                widget.emailMask,
                                widget.expiredAt,
                                widget.daDongYDieuKhoan,
                              );
                        }
                      : null,
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const AppText(
                'Đóng lại (để kiểm tra sau)',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            )
          ],
        ),
      ),
    );
  }
}
