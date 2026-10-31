import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatters/app_money_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../../contract/services/contract_pdf_service.dart';
import '../domain/enums/payment_method.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/payment_bloc.dart';
import '../bloc/payment_event.dart';
import '../bloc/payment_state.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment_model.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';

class PaymentPage extends StatefulWidget {
  final ContractModel contract;
  final PaymentRepository? repository;

  const PaymentPage({super.key, required this.contract, this.repository});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with WidgetsBindingObserver {
  PaymentMethod? _selectedPaymentMethod = PaymentMethod.vnpay;
  late PaymentBloc _paymentBloc;
  Key _qrImageKey = UniqueKey();
  // Presentation snapshot only: keep the visible QR during background reads.
  PaymentModel? _displayPayment;
  bool _hasLoaded = false;
  bool _explicitCheck = false;

  void _checkExplicitly(PaymentModel payment) {
    _explicitCheck = true;
    _paymentBloc.add(
      CheckPaymentStatus(
        widget.contract.contractId,
        paymentId: payment.maThanhToan,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paymentBloc = PaymentBloc(
      repository: widget.repository ?? PaymentRepository(),
    );
    _paymentBloc.add(LoadPaymentStatus(widget.contract.contractId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentBloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paymentBloc.add(LoadPaymentStatus(widget.contract.contractId));
    }
  }

  Future<void> _openVnpayUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đường dẫn thanh toán VNPAY không hợp lệ.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở trình duyệt để thanh toán.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở VNPAY: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onContinue() {
    if (_selectedPaymentMethod == null) return;
    _paymentBloc.add(
      CreatePaymentRequested(
        widget.contract.contractId,
        _selectedPaymentMethod!,
      ),
    );
  }

  void _handleBack() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/contract/${widget.contract.contractId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _paymentBloc,
      child: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentLoaded) {
            _hasLoaded = true;
            _displayPayment = state.activePayment;
            if (state.activePayment?.phuongThuc == 'TIEN_MAT') {
              _selectedPaymentMethod = PaymentMethod.cashOnHandover;
            }
          } else if (state is PaymentCreatePending) {
            _displayPayment = state.payment;
          } else if (state is PaymentOpenUrl) {
            _displayPayment = state.payment;
          } else if (state is PaymentStatusChecked) {
            _displayPayment = state.payment;
          }
          if (state is! PaymentChecking && state is! PaymentLoading) {
            _explicitCheck = false;
          }
          if (state is PaymentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is PaymentCreateSuccess) {
            context.replace('/payment/success', extra: widget.contract);
          } else if (state is PaymentOpenUrl) {
            _openVnpayUrl(state.url);
          } else if (state is PaymentCreatePending) {
            if (state.payment.phuongThuc == 'TIEN_MAT') {
              _showPendingPaymentDialog(context, state.payment);
            }
          } else if (state is PaymentStatusChecked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor:
                    state.isStillPending
                        ? Colors.orange.shade800
                        : Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is PaymentLoaded) {
            if (state.activePayment != null &&
                state.activePayment!.trangThai == 'THANH_CONG') {
              context.replace('/payment/success', extra: widget.contract);
            }
          }
        },
        builder: (context, state) {
          PaymentModel? activePayment = _displayPayment;
          if (state is PaymentLoaded) {
            activePayment = state.activePayment;
          } else if (state is PaymentCreatePending) {
            activePayment = state.payment;
          } else if (state is PaymentOpenUrl) {
            activePayment = state.payment;
          } else if (state is PaymentStatusChecked) {
            activePayment = state.payment;
          } else if (state is PaymentChecking && state.currentPayment != null) {
            activePayment = state.currentPayment;
          }

          final isChecking = state is PaymentChecking;
          final isPending =
              activePayment != null &&
              activePayment.trangThai == 'CHO_THANH_TOAN';
          final isBankTransferPending =
              isPending && activePayment.phuongThuc == 'CHUYEN_KHOAN';

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _handleBack();
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: _buildAppBar(context, isBankTransferPending),
              body: SnapLoadingOverlay(
                loading:
                    state is PaymentCreating ||
                    (state is PaymentChecking && _explicitCheck),
                message:
                    state is PaymentCreating
                        ? 'Đang gửi yêu cầu thanh toán'
                        : 'Đang kiểm tra trạng thái thanh toán',
                avoidKeyboardInsets: false,
                child:
                    !_hasLoaded &&
                            (state is PaymentInitial || state is PaymentLoading)
                        ? const SnapLoadingView(
                          message: 'Đang tải thông tin thanh toán',
                          size: RetroCameraLoader.large,
                        )
                        : Stack(
                          children: [
                            if (isBankTransferPending)
                              Column(
                                children: [
                                  const VerificationProgress(
                                    currentStep: 5,
                                    totalSteps: 5,
                                  ),
                                  Expanded(
                                    child: _buildBankTransferView(
                                      activePayment,
                                      isChecking,
                                    ),
                                  ),
                                  _buildBankTransferBottomBar(
                                    activePayment,
                                    isChecking,
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  const VerificationProgress(
                                    currentStep: 5,
                                    totalSteps: 5,
                                  ),
                                  Expanded(
                                    child: RefreshIndicator(
                                      onRefresh: () async {
                                        _paymentBloc.add(
                                          LoadPaymentStatus(
                                            widget.contract.contractId,
                                          ),
                                        );
                                      },
                                      child: SingleChildScrollView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 24,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _buildContractInfoCard(),
                                            const SizedBox(height: 24),
                                            _buildPaymentSummarySection(),
                                            if (activePayment != null &&
                                                activePayment.trangThai ==
                                                    'CHO_THANH_TOAN') ...[
                                              const SizedBox(height: 24),
                                              _buildPendingPaymentNotice(
                                                activePayment,
                                              ),
                                            ],
                                            const SizedBox(height: 24),
                                            _buildPaymentMethodSection(
                                              activePayment != null,
                                            ),
                                            const SizedBox(height: 24),
                                            _buildNoticesSection(),
                                            const SizedBox(height: 40),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildBottomBar(state, activePayment),
                                ],
                              ),
                            if (state is PaymentLoading ||
                                (state is PaymentChecking && !_explicitCheck))
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: SnapLoadingProgress(
                                  label: 'Đang cập nhật trạng thái thanh toán',
                                ),
                              ),
                          ],
                        ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPendingPaymentDialog(BuildContext context, PaymentModel payment) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.of(dialogContext).pop();
            _handleBack();
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppText(
                    'Đã ghi nhận yêu cầu!',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Yêu cầu thanh toán tiền cọc của bạn đã được ghi nhận thành công.',
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText(
                              'Trạng thái:',
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                            ),
                            AppText(
                              'Chờ thanh toán',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText(
                              'Tiền cọc:',
                              fontSize: 13,
                              color: Color(0xFF4B5563),
                            ),
                            AppText(
                              const AppMoneyFormatter().format(payment.soTien),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppText(
                    'Vui lòng thanh toán tiền cọc tại cửa hàng khi nhận thiết bị.',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade800,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'Xem chi tiết hợp đồng',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _handleBack();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingPaymentNotice(PaymentModel payment) {
    if (payment.phuongThuc == 'VI_DIEN_TU') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payment,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                AppText(
                  'Đang chờ thanh toán qua VNPAY',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              'Giao dịch cọc (${const AppMoneyFormatter().format(payment.soTien)}) qua VNPAY đang chờ bạn thanh toán hoặc chờ hệ thống cập nhật kết quả.',
              color: const Color(0xFF1E293B),
              fontSize: 13,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (payment.duongDanThanhToan != null &&
                    payment.duongDanThanhToan!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 16),
                      label: const Text('Mở VNPAY'),
                      onPressed:
                          () => _paymentBloc.add(
                            CreatePaymentRequested(
                              widget.contract.contractId,
                              PaymentMethod.vnpay,
                            ),
                          ),
                    ),
                  ),
                if (payment.duongDanThanhToan != null &&
                    payment.duongDanThanhToan!.isNotEmpty)
                  const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Kiểm tra'),
                    onPressed: () {
                      _checkExplicitly(payment);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_filled,
                color: Colors.orange.shade800,
                size: 20,
              ),
              const SizedBox(width: 8),
              AppText(
                'Chờ thanh toán tại cửa hàng',
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            'Yêu cầu thanh toán tiền cọc (${const AppMoneyFormatter().format(payment.soTien)}) bằng phương thức Tiền mặt đã được ghi nhận.',
            color: Colors.orange.shade900,
            fontSize: 13,
          ),
          const SizedBox(height: 4),
          AppText(
            'Vui lòng thanh toán trực tiếp cho nhân viên khi đến cửa hàng nhận thiết bị.',
            color: Colors.orange.shade900,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool isBankTransfer) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: _handleBack,
      ),
      title: AppText(
        isBankTransfer ? 'Thanh toán tiền cọc' : 'Thanh Toán',
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: UserAvatar(radius: 16),
        ),
      ],
    );
  }

  Widget _buildContractInfoCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    Icons.assignment_turned_in,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppText(
                            'Mã HĐ: ',
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          Expanded(
                            child: AppText(
                              widget.contract.contractId,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 10,
                            ),
                            SizedBox(width: 4),
                            AppText(
                              'Đã ký',
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.push('/contract/preview', extra: widget.contract);
            },
            child: Row(
              children: [
                AppText(
                  'Xem bản ký',
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.open_in_new,
                  color: Theme.of(context).colorScheme.primary,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummarySection() {
    const currencyFormat = AppMoneyFormatter();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const AppText(
                  'Tóm tắt thanh toán',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppText(
                '${widget.contract.rentalDays} ngày thuê',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSummaryRow(
          'Tiền thuê máy & lens',
          currencyFormat.format(widget.contract.rentalTotal),
          hasInfoIcon: true,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppText(
                  'Tiền cọc thiết bị ',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                AppText(
                  '(Hoàn lại 100%)',
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ],
            ),
            AppText(
              currencyFormat.format(widget.contract.deposit),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Tổng dự kiến',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                SizedBox(height: 4),
                AppText(
                  'Bao gồm cọc hoàn lại khi nhận lại máy',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ],
            ),
            AppText(
              currencyFormat.format(widget.contract.totalAmount),
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool hasInfoIcon = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            AppText(
              label,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
            if (hasInfoIcon) ...[
              SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 14,
              ),
            ],
          ],
        ),
        AppText(value, fontWeight: FontWeight.w600, fontSize: 13),
      ],
    );
  }

  Widget _buildPaymentMethodSection(bool hasActivePayment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Chọn phương thức thanh toán',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        SizedBox(height: 4),
        AppText(
          'Vui lòng chọn hình thức thanh toán thuận tiện nhất với bạn.',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        const SizedBox(height: 16),
        _buildPaymentMethodCard(
          method: PaymentMethod.vnpay,
          title: 'Thanh toán qua VNPAY',
          description: 'Cổng thanh toán điện tử VNPAY (VNPAY-QR Sandbox)',
          icon: Icons.qr_code_scanner,
          badge: 'Khuyên dùng',
          infoBox:
              'Quét mã VNPAY-QR bằng ứng dụng ngân hàng hoặc ví VNPAY. Giao dịch tự động xác nhận.',
          infoBoxIcon: Icons.bolt,
          isDisabled: hasActivePayment,
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(
          method: PaymentMethod.cashOnHandover,
          title: 'Thanh toán khi bàn giao',
          description: 'Tiền mặt tại cửa hàng khi nhận thiết bị',
          icon: Icons.storefront,
          infoBox: widget.contract.branchName,
          infoBoxIcon: Icons.location_on_outlined,
          isDisabled: hasActivePayment,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required PaymentMethod method,
    required String title,
    required String description,
    required IconData icon,
    String? badge,
    String? infoBox,
    IconData? infoBoxIcon,
    bool isDisabled = false,
  }) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap:
          isDisabled
              ? null
              : () {
                setState(() {
                  _selectedPaymentMethod = method;
                });
              },
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                title,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7E6),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: AppText(
                                  badge,
                                  color: const Color(0xFFD46B08),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 4),
                        AppText(
                          description,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                        width: isSelected ? 6 : 1,
                      ),
                    ),
                  ),
                ],
              ),
              if (infoBox != null) ...[
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.only(left: 48),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (infoBoxIcon != null) ...[
                        Icon(
                          infoBoxIcon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                      ],
                      Expanded(
                        child: AppText(
                          infoBox,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            SizedBox(width: 8),
            AppText(
              'Lưu ý dành cho người thuê',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildNoticeBullet(
          'Hợp đồng điện tử ${widget.contract.contractId} đã hoàn tất ký xác nhận và có giá trị pháp lý đầy đủ.',
        ),
        const SizedBox(height: 8),
        _buildNoticeBullet(
          _selectedPaymentMethod == PaymentMethod.cashOnHandover
              ? 'Chọn tiền mặt chỉ tạo yêu cầu chờ thanh toán. Nhân viên cửa hàng xác nhận khoản thu sau khi nhận tiền.'
              : 'Hình thức trực tuyến giúp thiết bị được giữ ngay lập tức khi hệ thống nhận mã không cần chờ duyệt thủ công.',
        ),
        const SizedBox(height: 8),
        _buildNoticeBullet(
          _selectedPaymentMethod == PaymentMethod.cashOnHandover
              ? 'Tiền cọc được xử lý theo hợp đồng và kết quả kiểm tra khi trả thiết bị; chọn tiền mặt chưa xác nhận đã thu hoặc đã hoàn tiền.'
              : 'Khoản tiền cọc 5.000.000đ sẽ được hoàn trả tự động vào tài khoản của bạn trong 2 giờ sau khi kỹ thuật viên nghiệm thu bàn giao máy.',
        ),
      ],
    );
  }

  Widget _buildNoticeBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 4, right: 8),
          child: Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
        ),
        Expanded(
          child: AppText(
            text,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(PaymentState state, PaymentModel? activePayment) {
    const currencyFormat = AppMoneyFormatter();
    final isProcessing = state is PaymentLoading || state is PaymentCreating;
    final isChecking = state is PaymentChecking;
    final hasActivePayment = activePayment != null;
    final isVnpayPending =
        hasActivePayment &&
        activePayment.phuongThuc == 'VI_DIEN_TU' &&
        activePayment.trangThai == 'CHO_THANH_TOAN';
    final isCashPending =
        hasActivePayment &&
        activePayment.phuongThuc == 'TIEN_MAT' &&
        activePayment.trangThai == 'CHO_THANH_TOAN';

    String buttonText = 'Tiếp tục →';
    VoidCallback? buttonAction = _onContinue;

    if (isVnpayPending || isCashPending) {
      buttonText = isChecking ? 'Đang kiểm tra...' : 'Kiểm tra trạng thái';
      buttonAction = isChecking ? null : () => _checkExplicitly(activePayment);
    } else if (hasActivePayment) {
      buttonText = 'Đã ghi nhận yêu cầu';
      buttonAction = null;
    } else if (_selectedPaymentMethod == null || isProcessing) {
      buttonAction = null;
    }

    String hintText;
    if (isVnpayPending) {
      hintText =
          'Giao dịch VNPAY đang chờ xử lý. Nhấn "Kiểm tra trạng thái" để cập nhật kết quả mới nhất.';
    } else if (isCashPending) {
      hintText =
          'Đang chờ nhân viên xác nhận đã thu tiền mặt. Nhấn "Kiểm tra trạng thái" để cập nhật kết quả.';
    } else if (hasActivePayment) {
      hintText =
          'Yêu cầu đã được ghi nhận. Theo dõi trạng thái thanh toán trong chi tiết hợp đồng.';
    } else if (_selectedPaymentMethod == PaymentMethod.cashOnHandover) {
      hintText = 'Vui lòng thanh toán tiền cọc tại cửa hàng khi nhận thiết bị.';
    } else {
      hintText =
          'Bước tiếp theo: Mở cổng thanh toán VNPAY Sandbox để xác nhận tiền cọc.';
    }

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
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Tiền cọc cần thanh toán',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      currencyFormat.format(
                        isCashPending
                            ? activePayment.soTien
                            : widget.contract.deposit,
                      ),
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  text: buttonText,
                  onPressed: buttonAction,
                  isLoading: isProcessing || isChecking,
                  showLoadingAnimation: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppText(
            hintText,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBankTransferView(PaymentModel payment, bool isChecking) {
    const currencyFormat = AppMoneyFormatter();
    final bankName = payment.nganHang?.trim() ?? '';
    final binCode = payment.maBin?.trim() ?? '';
    final accountNo = payment.soTaiKhoan?.trim() ?? '';
    final accountName = payment.chuTaiKhoan?.trim() ?? '';
    final amountStr = currencyFormat.format(payment.soTien);
    final content = payment.noiDungChuyenKhoan?.trim() ?? '';
    if ([
          bankName,
          binCode,
          accountNo,
          accountName,
          content,
        ].any((value) => value.isEmpty) ||
        payment.soTien <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Backend chưa cung cấp đủ thông tin chuyển khoản. Hãy kiểm tra lại trước khi thanh toán.',
              ),
              TextButton(
                onPressed: isChecking ? null : () => _checkExplicitly(payment),
                child: const AppText('Kiểm tra trạng thái'),
              ),
            ],
          ),
        ),
      );
    }

    final qrUrl =
        'https://img.vietqr.io/image/$binCode-$accountNo-compact.png?amount=${payment.soTien}&addInfo=${Uri.encodeComponent(content)}&accountName=${Uri.encodeComponent(accountName)}';

    return RefreshIndicator(
      onRefresh: () async {
        _paymentBloc.add(
          CheckPaymentStatus(
            widget.contract.contractId,
            paymentId: payment.maThanhToan,
          ),
        );
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildContractInfoCard(),
            const SizedBox(height: 16),
            // Trạng thái chờ xác nhận
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.hourglass_top,
                      color: Colors.orange.shade900,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Chờ xác nhận chuyển khoản',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange.shade900,
                        ),
                        const SizedBox(height: 2),
                        AppText(
                          'Sau khi chuyển khoản, vui lòng chờ cửa hàng xác nhận.',
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Mã QR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const AppText(
                    'Mã QR chuyển khoản',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    'Quét mã bằng app ngân hàng bất kỳ (Napas 247)',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        qrUrl,
                        key: _qrImageKey,
                        width: 204,
                        height: 204,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.wifi_off_rounded,
                                    color: Colors.grey.shade500,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  AppText(
                                    'Không tải được mã QR',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _qrImageKey = UniqueKey();
                                      });
                                    },
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text(
                                      'Thử lại',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    'Nếu không quét được mã, bạn có thể sao chép thông tin bên dưới để chuyển khoản thủ công.',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Thông tin tài khoản nhận tiền
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const AppText(
                        'Thông tin tài khoản nhận tiền',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTransferInfoRow(
                    'Ngân hàng',
                    '$bankName (BIN: $binCode)',
                  ),
                  const Divider(height: 20),
                  _buildTransferInfoRow(
                    'Chủ tài khoản',
                    accountName,
                    isBold: true,
                  ),
                  const Divider(height: 20),
                  _buildAccountNumberRow(accountNo),
                  const Divider(height: 20),
                  _buildTransferInfoRow(
                    'Số tiền cọc',
                    amountStr,
                    isHighlight: true,
                  ),
                  const Divider(height: 20),
                  _buildTransferContentSection(content),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Lưu ý
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      AppText(
                        'Lưu ý quan trọng',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildNoticeBullet(
                    'Sau khi chuyển khoản, vui lòng chờ cửa hàng xác nhận.',
                  ),
                  const SizedBox(height: 6),
                  _buildNoticeBullet(
                    'Vui lòng giữ nguyên nội dung chuyển khoản để hệ thống đối soát chính xác.',
                  ),
                  const SizedBox(height: 6),
                  _buildNoticeBullet(
                    'Không chuyển lại nếu tài khoản ngân hàng của bạn đã bị trừ tiền.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBankTransferBottomBar(PaymentModel payment, bool isChecking) {
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
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: isChecking ? 'Đang kiểm tra...' : 'Kiểm tra trạng thái',
              isLoading: isChecking,
              showLoadingAnimation: false,
              onPressed:
                  isChecking
                      ? null
                      : () {
                        _checkExplicitly(payment);
                      },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _handleBack,
              child: AppText(
                'Quay lại chi tiết hợp đồng',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppText(
            value,
            textAlign: TextAlign.right,
            fontWeight:
                isHighlight || isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 15 : 13,
            color:
                isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountNumberRow(String accountNo) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppText(
          'Số tài khoản',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: AppText(
                  accountNo,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              _buildCopyButton(accountNo, 'Đã sao chép số tài khoản'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferContentSection(String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Nội dung chuyển khoản',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppText(
                content,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            _buildCopyButton(content, 'Đã sao chép nội dung chuyển khoản'),
          ],
        ),
      ],
    );
  }

  Widget _buildCopyButton(String copyText, String snackbarMsg) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        Clipboard.setData(ClipboardData(text: copyText));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackbarMsg),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            AppText(
              'Sao chép',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
