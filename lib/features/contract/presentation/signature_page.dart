import '../../../core/widgets/snap_loading_view.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/models/rental_terms.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../domain/models/signature_result_model.dart';
import '../services/contract_pdf_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/contract_signing_cubit.dart';
import 'bloc/contract_signing_state.dart';
import 'widgets/signature_result_dialog.dart';
import 'widgets/otp_verification_dialog.dart';

class SignaturePage extends StatefulWidget {
  final ContractModel contract;

  const SignaturePage({super.key, required this.contract});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late SignatureController _signatureController;
  bool _confirmOwnSignature = false;
  bool _acceptContractTerms = false;
  bool _hasSignature = false;
  bool _isInitialized = false;
  Uint8List? _generatedPdfBytes;
  bool _isGeneratingPdf = false;
  bool _otpDialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _signatureController = SignatureController(
        penStrokeWidth: 3,
        penColor: Theme.of(context).colorScheme.primary,
        exportBackgroundColor: Colors.transparent,
        onDrawEnd: () {
          _generatedPdfBytes = null;
          setState(() {
            _hasSignature = _signatureController.isNotEmpty;
          });
        },
      );
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  void _clearSignature() {
    _signatureController.clear();
    _generatedPdfBytes = null;
    setState(() {
      _hasSignature = false;
    });
  }

  bool get _canSubmit =>
      _hasSignature &&
      _confirmOwnSignature &&
      _acceptContractTerms &&
      !_isGeneratingPdf;

  Future<Uint8List?> _getOrGeneratePdfBytes() async {
    if (_generatedPdfBytes != null) return _generatedPdfBytes;
    setState(() => _isGeneratingPdf = true);
    try {
      if (_hasSignature) {
        final signatureBytes = await _signatureController.toPngBytes();
        if (signatureBytes != null) {
          _generatedPdfBytes = await ContractPdfService().generateContractPdf(
            widget.contract,
            signaturePngBytes: signatureBytes,
          );
        }
      } else {
        _generatedPdfBytes = await ContractPdfService().generateContractPdf(
          widget.contract,
        );
      }
      return _generatedPdfBytes;
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _submitSignature() async {
    if (!_canSubmit) return;

    final pdfBytes = await _getOrGeneratePdfBytes();
    if (pdfBytes == null) return;

    if (!mounted) return;
    context.read<ContractSigningCubit>().requestOtp(
      widget.contract,
      pdfBytes,
      _acceptContractTerms,
    );
  }

  Future<void> _showOtpDialog(
    String maXacNhan,
    String emailMask,
    DateTime expiredAt,
  ) async {
    if (!mounted || _otpDialogOpen) return;
    _otpDialogOpen = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return BlocProvider.value(
            value: context.read<ContractSigningCubit>(),
            child: OtpVerificationDialog(
              contract: widget.contract,
              maXacNhan: maXacNhan,
              emailMask: emailMask,
              expiredAt: expiredAt,
              daDongYDieuKhoan: _acceptContractTerms,
            ),
          );
        },
      );
    } finally {
      _otpDialogOpen = false;
    }
  }

  void _showResultDialog(
    bool isSuccess, [
    String? error,
    ContractModel? updatedContract,
  ]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return SignatureResultDialog(
          isSuccess: isSuccess,
          errorMessage: error,
          onPrimaryPressed: () {
            Navigator.of(ctx).pop(); // Close dialog
            if (isSuccess && updatedContract != null) {
              context.pushReplacement('/payment', extra: updatedContract);
            } else {
              // Retry logic for failure
              _submitSignature();
            }
          },
          onClosePressed: () {
            Navigator.of(ctx).pop(); // Close dialog

            if (isSuccess && updatedContract != null && mounted) {
              context.go('/');
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContractSigningCubit, ContractSigningState>(
      listener: (context, state) {
        if (state is ContractSigningOtpSent) {
          _showOtpDialog(state.maXacNhan, state.emailMask, state.expiredAt);
        } else if (state is ContractSigningSuccess) {
          if (_otpDialogOpen) Navigator.of(context).pop();
          _showResultDialog(true, null, state.updatedContract);
        } else if (state is ContractSigningFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: _buildAppBar(context),
        body: BlocBuilder<ContractSigningCubit, ContractSigningState>(
          builder:
              (context, state) => SnapLoadingOverlay(
                loading:
                    (ModalRoute.of(context)?.isCurrent ?? true) &&
                    (state is ContractSigningLoading || _isGeneratingPdf),
                message:
                    _isGeneratingPdf
                        ? 'Đang chuẩn bị tài liệu hợp đồng'
                        : 'Đang gửi yêu cầu ký hợp đồng',
                avoidKeyboardInsets: false,
                child: Column(
                  children: [
                    const VerificationProgress(currentStep: 4, totalSteps: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInstructionCard(),
                            const SizedBox(height: 24),
                            _buildContractSummary(context),
                            const SizedBox(height: 24),
                            _buildSignatureSection(),
                            const SizedBox(height: 24),
                            _buildSignerVerification(),
                            const SizedBox(height: 24),
                            _buildCheckboxes(),
                            const SizedBox(height: 24),
                            _buildWarningCard(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                    BlocBuilder<ContractSigningCubit, ContractSigningState>(
                      builder: (context, state) {
                        final isLoading =
                            state is ContractSigningLoading || _isGeneratingPdf;
                        return _buildBottomBar(isLoading);
                      },
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => context.pop(),
      ),
      title: Column(
        children: [
          const AppText(
            'Ký Hợp Đồng',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          AppText(
            'Bước xác nhận cuối',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: UserAvatar(radius: 16),
        ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Xác nhận chữ ký hợp đồng',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                SizedBox(height: 4),
                AppText(
                  'Vui lòng ký tên bằng tay để xác nhận bạn đồng ý với điều khoản thuê thiết bị máy ảnh.',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractSummary(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppText(
              'Tóm tắt hợp đồng',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            GestureDetector(
              onTap: () async {
                final pdfBytes = await _getOrGeneratePdfBytes();
                if (!context.mounted) return;
                final previewContract =
                    pdfBytes != null
                        ? widget.contract.copyWith(
                          signatureResult: SignatureResultModel(
                            contractId: widget.contract.contractId,
                            pdfBytes: pdfBytes,
                            pdfSha256: '', // Dummy for preview
                            signaturePngBytes: Uint8List(0),
                            signerName: '',
                            signedAt: DateTime.now(),
                            publicKey: '',
                            nonce: '',
                            signedMessage: '',
                            cryptographicSignature: '',
                            isVerified: false,
                          ),
                        )
                        : widget.contract;
                context.push('/contract/preview', extra: previewContract);
              },
              child: AppText(
                'Xem lại chi tiết',
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryRow('Mã HĐ', widget.contract.contractId),
              _buildSummaryRow('Status', 'Chờ ký', valueColor: Colors.orange),
              _buildSummaryRow('Ngày', dateFormat.format(widget.contract.date)),
              _buildSummaryRow('Người thuê', widget.contract.lesseeName),
              _buildSummaryRow('Thiết bị', widget.contract.deviceName),
              _buildSummaryRow(
                'Thời gian thuê',
                '${dateFormat.format(widget.contract.pickupDate)} → ${dateFormat.format(widget.contract.returnDate)}',
              ),
              _buildSummaryRow('Tổng', '${widget.contract.rentalDays} ngày'),
              _buildSummaryRow('Chi nhánh', widget.contract.branchName),
              const Divider(height: 24),
              _buildSummaryRow(
                'Tiền thuê',
                currencyFormat.format(widget.contract.rentalTotal),
              ),
              _buildSummaryRow(
                'Tiền cọc',
                currencyFormat.format(widget.contract.deposit),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText(
                    'Tổng thanh toán dự kiến',
                    fontWeight: FontWeight.w600,
                  ),
                  AppText(
                    currencyFormat.format(widget.contract.totalAmount),
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppText(
              label,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          Expanded(
            flex: 3,
            child: AppText(
              value,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 13,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              'Chữ ký khách hàng',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: AppText(
                'Bắt buộc',
                color: Theme.of(context).colorScheme.error,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: AppText(
                  'VÙNG KÝ - CHUẨN',
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _hasSignature ? _clearSignature : null,
              icon: const Icon(Icons.clear, size: 16),
              label: AppText('Xóa nét ký', fontSize: 13),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _hasSignature ? _clearSignature : null,
              icon: const Icon(Icons.refresh, size: 16),
              label: AppText('Ký lại mẫu khác', fontSize: 13),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        AppText(
          'Bản thử nghiệm: nét ký được đưa vào PDF; chữ ký số được tạo và kiểm tra cục bộ trên thiết bị. Chưa kết nối xác minh với máy chủ.',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignerVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              'Xác nhận người ký',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .extension<AppColorsExtension>()!
                    .success
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color:
                        Theme.of(
                          context,
                        ).extension<AppColorsExtension>()!.success,
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  AppText(
                    'Đã xác minh',
                    color:
                        Theme.of(
                          context,
                        ).extension<AppColorsExtension>()!.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            children: [
              _buildSummaryRow('Họ và tên', widget.contract.lesseeName),
              _buildSummaryRow('CCCD gắn chip', widget.contract.lesseeId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxes() {
    return Column(
      children: [
        if (widget.contract.termsVersion == RentalTerms.version)
          ExpansionTile(
            title: const Text('Điều khoản thuê ${RentalTerms.version}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(RentalTerms.text),
              ),
            ],
          ),
        _buildCheckboxRow(
          value: _confirmOwnSignature,
          onChanged: (val) {
            setState(() {
              _confirmOwnSignature = val ?? false;
            });
          },
          text: 'Tôi xác nhận chữ ký trên là chữ ký hợp lệ của chính tôi.',
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow(
          value: _acceptContractTerms,
          onChanged: (val) {
            setState(() {
              _acceptContractTerms = val ?? false;
            });
          },
          richText: TextSpan(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
            children: [
              const TextSpan(
                text:
                    'Tôi đã đọc, hiểu rõ và đồng ý toàn bộ điều khoản hợp đồng thuê máy ảnh và chính sách đền bù của ',
              ),
              TextSpan(
                text: 'SNAPLEASE',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    String? text,
    TextSpan? richText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              text != null
                  ? AppText(text, fontSize: 13)
                  : RichText(text: richText!),
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD591)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFA8C16),
                size: 20,
              ),
              SizedBox(width: 8),
              AppText(
                'Lưu ý quan trọng',
                color: Color(0xFFD46B08),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletText(
            'Sau khi ký xác nhận, hợp đồng điện tử sẽ được mã hóa và lưu trữ trên hệ thống.',
          ),
          const SizedBox(height: 8),
          _buildBulletText(
            'Bạn sẽ tiếp tục chuyển sang bước đặt cọc/thanh toán trực tuyến.',
          ),
          const SizedBox(height: 8),
          _buildBulletText(
            'Vui lòng kiểm tra kỹ tình trạng máy ảnh trước khi nhận bàn giao tại cửa hàng.',
          ),
        ],
      ),
    );
  }

  Widget _buildBulletText(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 8),
          child: CircleAvatar(radius: 2, backgroundColor: Color(0xFFD46B08)),
        ),
        Expanded(
          child: AppText(text, color: const Color(0xFF8C4004), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isLoading) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  'Tổng dự kiến',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                SizedBox(height: 4),
                AppText(
                  currencyFormat.format(widget.contract.totalAmount),
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: PrimaryButton(
              text: 'Xác nhận ký hợp đồng →',
              isLoading: isLoading,
              showLoadingAnimation: false,
              onPressed: _canSubmit && !isLoading ? _submitSignature : null,
            ),
          ),
        ],
      ),
    );
  }
}
