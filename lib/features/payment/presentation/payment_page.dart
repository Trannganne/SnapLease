import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../../contract/services/contract_pdf_service.dart';
import '../domain/enums/payment_method.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/payment_bloc.dart';
import '../bloc/payment_event.dart';
import '../bloc/payment_state.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment_model.dart';

class PaymentPage extends StatefulWidget {
  final ContractModel contract;

  const PaymentPage({super.key, required this.contract});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> with WidgetsBindingObserver {
  PaymentMethod? _selectedPaymentMethod = PaymentMethod.cashOnHandover;
  late PaymentBloc _paymentBloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _paymentBloc = PaymentBloc(repository: PaymentRepository());
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

  void _onContinue() {
    if (_selectedPaymentMethod == null) return;

    if (_selectedPaymentMethod == PaymentMethod.online) {
      // Placeholder cho flow thanh toán online / QR
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chuyển sang màn Thanh toán trực tuyến / QR Payment'),
        ),
      );
    } else {
      // Flow nhận máy
      _paymentBloc.add(CreatePaymentRequested(widget.contract.contractId, _selectedPaymentMethod!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _paymentBloc,
      child: BlocConsumer<PaymentBloc, PaymentState>(
        listener: (context, state) {
          if (state is PaymentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          } else if (state is PaymentCreateSuccess) {
            context.replace('/payment/success', extra: widget.contract);
          } else if (state is PaymentCreatePending) {
            _showPendingPaymentDialog(context, state.payment);
            _paymentBloc.add(LoadPaymentStatus(widget.contract.contractId));
          } else if (state is PaymentLoaded) {
            if (state.activePayment != null && state.activePayment!.trangThai == 'THANH_CONG') {
              context.replace('/payment/success', extra: widget.contract);
            }
          }
        },
        builder: (context, state) {
          PaymentModel? activePayment;
          if (state is PaymentLoaded) {
            activePayment = state.activePayment;
          } else if (state is PaymentCreatePending) {
            activePayment = state.payment;
          }

          final isPending = activePayment != null && activePayment.trangThai == 'CHO_THANH_TOAN';

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (isPending) {
                context.go('/contract/${widget.contract.contractId}');
              } else {
                context.pop();
              }
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: _buildAppBar(context, isPending),
              body: Stack(
                children: [
                  Column(
                    children: [
                      const VerificationProgress(currentStep: 5, totalSteps: 5),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                             _paymentBloc.add(LoadPaymentStatus(widget.contract.contractId));
                          },
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildContractInfoCard(),
                                const SizedBox(height: 24),
                                _buildPaymentSummarySection(),
                                if (activePayment != null && activePayment.trangThai == 'CHO_THANH_TOAN') ...[
                                  const SizedBox(height: 24),
                                  _buildPendingPaymentNotice(activePayment),
                                ],
                                const SizedBox(height: 24),
                                _buildPaymentMethodSection(activePayment != null),
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
                  if (state is PaymentLoading || state is PaymentCreating)
                     const Center(child: CircularProgressIndicator()),
                ],
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
            context.go('/contract/${widget.contract.contractId}');
          },
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            const AppText('Trạng thái:', fontSize: 13, color: Color(0xFF4B5563)),
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
                            const AppText('Tiền cọc:', fontSize: 13, color: Color(0xFF4B5563)),
                            AppText(
                              NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(payment.soTien),
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
                        context.go('/contract/${widget.contract.contractId}');
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
    return Container(
      padding: EdgeInsets.all(16),
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
              Icon(Icons.access_time_filled, color: Colors.orange.shade800, size: 20),
              SizedBox(width: 8),
              AppText(
                'Chờ thanh toán tại cửa hàng',
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ],
          ),
          SizedBox(height: 8),
          AppText(
            'Yêu cầu thanh toán tiền cọc (${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(payment.soTien)}) bằng phương thức ${payment.phuongThuc == 'TIEN_MAT' ? 'Tiền mặt' : 'Chuyển khoản'} đã được ghi nhận.',
            color: Colors.orange.shade900,
            fontSize: 13,
          ),
          SizedBox(height: 4),
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

  AppBar _buildAppBar(BuildContext context, bool isPending) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () {
          if (isPending) {
            context.go('/contract/${widget.contract.contractId}');
          } else {
            context.pop();
          }
        },
      ),
      title: const AppText(
        'Thanh Toán',
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

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
          method: PaymentMethod.online,
          title: 'Thanh toán trực tuyến',
          description: 'Chuyển khoản QR Napas 247 hoặc ví điện tử (Đang cập nhật)',
          icon: Icons.qr_code_scanner,
          badge: 'Khuyên dùng',
          infoBox: 'Hệ thống tự động kích hoạt lịch thuê ngay sau 30 giây',
          infoBoxIcon: Icons.flash_on,
          isDisabled: hasActivePayment,
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(
          method: PaymentMethod.cashOnHandover,
          title: 'Thanh toán khi bàn giao',
          description: 'Tiền mặt hoặc POS quẹt thẻ lúc nhận máy',
          icon: Icons.storefront,
          infoBox: 'Tại Showroom SNAPLEASE Quận 1\nhoặc Hub giao nhận',
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
      onTap: isDisabled ? null : () {
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
          'Hình thức trực tuyến giúp thiết bị được giữ ngay lập tức khi hệ thống nhận mã không cần chờ duyệt thủ công.',
        ),
        const SizedBox(height: 8),
        _buildNoticeBullet(
          'Khoản tiền cọc 5.000.000đ sẽ được hoàn trả tự động vào tài khoản của bạn trong 2 giờ sau khi kỹ thuật viên nghiệm thu bàn giao máy.',
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final isProcessing = state is PaymentLoading || state is PaymentCreating;
    final hasActivePayment = activePayment != null;

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
                      'Tổng thanh toán dự kiến',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    SizedBox(height: 2),
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
                child: PrimaryButton(
                  text: hasActivePayment ? 'Đã ghi nhận yêu cầu' : 'Tiếp tục →',
                  onPressed: (_selectedPaymentMethod != null && !isProcessing && !hasActivePayment) ? _onContinue : null,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppText(
            hasActivePayment
                ? 'Yêu cầu đã được ghi nhận. Theo dõi trạng thái thanh toán trong chi tiết hợp đồng.'
                : (_selectedPaymentMethod == PaymentMethod.cashOnHandover
                    ? 'Vui lòng thanh toán tiền cọc tại cửa hàng khi nhận thiết bị.'
                    : 'Bước tiếp theo: Hiển thị mã QR ngân hàng.'),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
