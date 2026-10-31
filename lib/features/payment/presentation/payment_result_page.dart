import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/formatters/app_money_formatter.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment_model.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';

class PaymentResultPage extends StatefulWidget {
  final String paymentId;
  final PaymentRepository? repository;

  const PaymentResultPage({
    super.key,
    required this.paymentId,
    this.repository,
  });

  @override
  State<PaymentResultPage> createState() => _PaymentResultPageState();
}

class _PaymentResultPageState extends State<PaymentResultPage>
    with WidgetsBindingObserver {
  late final PaymentRepository _repository;
  bool _checking = false;
  int _generation = 0;
  bool _isLoading = true;
  String? _errorMessage;
  PaymentModel? _payment;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PaymentRepository();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PaymentResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paymentId != widget.paymentId) {
      ++_generation;
      _checking = false;
      _checkStatus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus(reconcile: false);
  }

  Future<void> _checkStatus({bool reconcile = true}) async {
    if (_checking) return;
    _checking = true;
    final generation = ++_generation;
    final paymentId = widget.paymentId;
    if (widget.paymentId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Thiếu mã thanh toán trong liên kết chuyển tiếp.';
      });
      _checking = false;
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var payment = await _repository.getPaymentById(paymentId);
      if (reconcile &&
          payment.trangThai == 'CHO_THANH_TOAN' &&
          payment.nhaCungCap == 'VNPAY') {
        payment = await _repository.reconcileVnpayPayment(paymentId);
      }
      if (mounted && generation == _generation) {
        setState(() {
          _payment = payment;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Chưa xác định trạng thái giao dịch do lỗi kết nối. Vui lòng thử lại.';
        });
      }
    } finally {
      if (generation == _generation) _checking = false;
    }
  }

  void _navigateBack() {
    if (!mounted) return;
    if (_payment != null && _payment!.maHopDong.isNotEmpty) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/contract/${_payment!.maHopDong}');
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/?tab=contracts');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const currencyFormat = AppMoneyFormatter();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const AppText(
            'Kết quả thanh toán',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
        ),
        body: SnapLoadingOverlay(
          loading: _isLoading && _payment != null,
          message: 'Đang kiểm tra kết quả thanh toán',
          avoidKeyboardInsets: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child:
                  _isLoading && _payment == null
                      ? const SnapLoadingView(
                        message: 'Đang xác minh trạng thái thanh toán',
                        size: RetroCameraLoader.large,
                      )
                      : _buildContent(currencyFormat),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppMoneyFormatter currencyFormat) {
    if (_errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          AppText(
            _errorMessage!,
            textAlign: TextAlign.center,
            color: const Color(0xFF4B5563),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Kiểm tra lại',
            isLoading: _isLoading,
            showLoadingAnimation: false,
            onPressed: _checkStatus,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _navigateBack,
            child: const AppText('Về chi tiết hợp đồng'),
          ),
        ],
      );
    }

    if (_payment == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const AppText('Không tìm thấy thông tin giao dịch.'),
          const SizedBox(height: 24),
          PrimaryButton(text: 'Về hợp đồng', onPressed: _navigateBack),
        ],
      );
    }

    final isSuccess = _payment!.trangThai == 'THANH_CONG';
    final isPending =
        _payment!.trangThai == 'CHO_THANH_TOAN' &&
        !_payment!.lastVnpayAttemptFailed;
    final isSettlement = _payment!.loaiThanhToan == 'THU_QUYET_TOAN';

    final Color statusColor =
        isSuccess
            ? Colors.green
            : (isPending ? Colors.orange.shade800 : Colors.red);
    final IconData statusIcon =
        isSuccess
            ? Icons.check_circle_rounded
            : (isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded);
    final String statusTitle =
        isSuccess
            ? (isSettlement
                ? 'Thanh toán quyết toán thành công!'
                : 'Thanh toán tiền cọc thành công!')
            : (isPending
                ? 'Đang chờ xác nhận từ VNPAY'
                : 'Thanh toán không thành công');
    final String statusDesc =
        isSuccess
            ? (isSettlement
                ? 'Khoản còn thiếu đã được hệ thống ghi nhận. Hãy về hợp đồng để kiểm tra quyết toán và xác nhận phù hợp.'
                : 'Khoản tiền cọc đã được hệ thống ghi nhận thành công.')
            : (isPending
                ? 'Chưa xác minh được kết quả từ VNPAY. Vui lòng bấm "Kiểm tra lại"; không thanh toán lại khoản này.'
                : 'Yêu cầu VNPAY vừa kiểm tra đã bị hủy hoặc không thành công. Khoản thu chưa được ghi nhận.');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(statusIcon, size: 72, color: statusColor),
        const SizedBox(height: 16),
        AppText(
          statusTitle,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: statusColor,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppText(
          statusDesc,
          textAlign: TextAlign.center,
          color: const Color(0xFF4B5563),
          fontSize: 14,
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
              _buildDetailRow('Mã giao dịch:', _payment!.maThanhToan),
              const SizedBox(height: 8),
              _buildDetailRow('Mã hợp đồng:', _payment!.maHopDong),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Số tiền cọc:',
                currencyFormat.format(_payment!.soTien),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Phương thức:', _payment!.nhaCungCap ?? 'VNPAY'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        if (isPending) ...[
          PrimaryButton(
            text: 'Kiểm tra lại',
            isLoading: _isLoading,
            showLoadingAnimation: false,
            onPressed: _checkStatus,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _navigateBack,
            child: const AppText('Về chi tiết hợp đồng'),
          ),
        ] else ...[
          PrimaryButton(text: 'Về chi tiết hợp đồng', onPressed: _navigateBack),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(label, fontSize: 13, color: const Color(0xFF64748B)),
        AppText(value, fontSize: 13, fontWeight: FontWeight.w600),
      ],
    );
  }
}
