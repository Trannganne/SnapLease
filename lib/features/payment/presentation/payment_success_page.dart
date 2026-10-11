import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../contract/services/contract_pdf_service.dart';

class PaymentSuccessPage extends StatelessWidget {
  final ContractModel contract;

  const PaymentSuccessPage({super.key, required this.contract});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent going back accidentally
        title: AppText(
          'Hoàn tất đặt thuê',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSuccessHeader(context),
              const SizedBox(height: 32),
              _buildContractIdCard(context),
              const SizedBox(height: 16),
              _buildDeviceInfoCard(context),
              const SizedBox(height: 16),
              _buildPaymentSummaryCard(context),
              const SizedBox(height: 16),
              _buildWarningCard(context),
              const SizedBox(height: 40),
              PrimaryButton(
                text: 'Theo dõi hợp đồng thuê  →',
                onPressed: () {
                  // Currently we don't have a route for tracking yet, we will add it to app_router
                  context.push('/contract/tracking', extra: contract);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 20),
                  label: const Text('Xem hợp đồng'),
                  onPressed: () {
                    context.push('/contract/preview', extra: contract);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    context.go('/');
                  },
                  child: AppText(
                    'Về trang chủ',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppText(
          'Thanh toán tiền cọc thành công',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        AppText(
          'Khoản thanh toán tiền cọc đã được xác nhận thành công.',
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AppText(
          'Vui lòng đến đúng chi nhánh vào thời gian nhận thiết bị.',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildContractIdCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'MÃ HỢP ĐỒNG',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppText(
                        contract.contractId,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: contract.contractId),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã hợp đồng'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: AppText(
                  _getBadgeText(contract.status),
                  color: Colors.orange.shade800,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    'Hình thức thanh toán',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AppText(
                'Thanh toán khi bàn giao',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    'Trạng thái',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AppText(
                'Đã thanh toán cọc',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              AppText(
                'Thông tin thiết bị',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      contract.deviceName,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      contract.deviceModel,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      'Số lượng: ${contract.quantity}',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Ngày nhận',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      DateFormat('dd/MM/yyyy').format(contract.pickupDate),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'Thời gian',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      DateFormat('HH:mm').format(contract.pickupDate),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                'Chi nhánh',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              AppText(
                contract.branchName,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    'Thanh toán khi bàn giao',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AppText(
                  'Dự kiến',
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                'Tiền thuê thiết bị',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              AppText(
                currencyFormatter.format(contract.rentalTotal),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                'Tiền đặt cọc',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              AppText(
                currencyFormatter.format(contract.deposit),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Tổng dự kiến',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    'Đã bao gồm tiền cọc',
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              AppText(
                currencyFormatter.format(contract.totalAmount),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Vui lòng thanh toán trực tiếp tại cửa hàng',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        'Số tiền cuối cùng sẽ được xác nhận theo hợp đồng và tình trạng thực tế của thiết bị.',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(BuildContext context) {
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
                Icons.warning_amber_rounded,
                size: 20,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              AppText(
                'Lưu ý khi nhận thiết bị',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletPoint(
            context,
            'Mang theo CCCD bản gốc để đối chiếu khi nhận thiết bị.',
          ),
          const SizedBox(height: 8),
          _buildBulletPoint(
            context,
            'Kiểm tra kỹ tình trạng thiết bị, sensor và phụ kiện trước khi nhận.',
          ),
          const SizedBox(height: 8),
          _buildBulletPoint(
            context,
            'Thanh toán theo phương thức đã chọn trong hợp đồng.',
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, right: 8.0, left: 4.0),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.orange.shade800,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: AppText(
            text,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _getBadgeText(String? status) {
    switch (status) {
      case 'CHO_KY': return 'Chờ ký';
      case 'DA_KY': return 'Chờ thanh toán';
      case 'CHO_BAN_GIAO': return 'Chờ bàn giao';
      case 'DANG_THUE': return 'Đang thuê';
      case 'HOAN_THANH': return 'Hoàn tất';
      case 'DA_HUY': return 'Đã hủy';
      default: return 'Không rõ';
    }
  }
}
