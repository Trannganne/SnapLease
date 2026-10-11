import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';

class SignatureDialogColors {
  static const Color buttonPurple = Color(0xFF6B4EFF);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color infoBackground = Color(0xFFF3F4F6);
}

class SignatureResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String? errorMessage;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onClosePressed;

  const SignatureResultDialog({
    super.key,
    required this.isSuccess,
    this.errorMessage,
    required this.onPrimaryPressed,
    required this.onClosePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(height: 16),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildInfoBox(),
            const SizedBox(height: 32),
            _buildPrimaryButton(context),
            const SizedBox(height: 8),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final Color outerColor = isSuccess ? SignatureDialogColors.successLight : SignatureDialogColors.errorLight;
    final Color innerColor = isSuccess ? SignatureDialogColors.successGreen : SignatureDialogColors.errorRed;
    final IconData iconData = isSuccess ? Icons.check : Icons.close;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: outerColor,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: innerColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return AppText(
      isSuccess ? 'Xác minh chữ ký thành công' : 'Xác minh chữ ký thất bại',
      fontSize: 18,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription() {
    return AppText(
      isSuccess
          ? 'Chữ ký số của hợp đồng mẫu đã được kiểm tra thành công trên thiết bị.'
          : 'Không thể xác minh chữ ký của hợp đồng mẫu. Vui lòng thử lại.',
      fontSize: 14,
      color: const Color(0xFF4B5563), // Tailwind gray-600 equivalent
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInfoBox() {
    final bgColor = isSuccess ? SignatureDialogColors.infoBackground : SignatureDialogColors.errorLight;
    final borderColor = isSuccess ? Colors.transparent : SignatureDialogColors.errorRed.withValues(alpha: 0.2);
    final iconData = isSuccess ? Icons.lock_outline : Icons.warning_amber_rounded;
    final iconColor = isSuccess ? const Color(0xFF4B5563) : SignatureDialogColors.errorRed;
    final textColor = isSuccess ? const Color(0xFF1F2937) : SignatureDialogColors.errorRed;
    
    // Map error message
    String displayError = 'Chưa thể xác minh chữ ký. Vui lòng thử lại.';
    if (!isSuccess && errorMessage != null && errorMessage!.isNotEmpty) {
      // Basic mapping to avoid raw exceptions
      if (errorMessage!.toLowerCase().contains('timeout')) {
        displayError = 'Quá thời gian kết nối. Vui lòng thử lại.';
      } else if (errorMessage!.toLowerCase().contains('network')) {
        displayError = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại.';
      } else {
        displayError = 'Chưa thể xác minh chữ ký. Vui lòng thử lại.'; // Fallback as requested
      }
    }

    final text = isSuccess ? 'Thuật toán: RSA • SHA-256' : displayError;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: SignatureDialogColors.buttonPurple,
        ),
      ),
      child: PrimaryButton(
        text: isSuccess ? 'Tiếp tục thanh toán' : 'Thử lại',
        onPressed: onPrimaryPressed,
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onClosePressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const AppText(
          'Đóng',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}
