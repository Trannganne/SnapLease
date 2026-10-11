import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/widgets/app_text.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../services/contract_pdf_service.dart';
import '../tracking/models/contract_tracking_status.dart';
import '../tracking/widgets/contract_tracking_summary_card.dart';

class ContractRenewalPage extends StatefulWidget {
  final ContractModel contract;

  const ContractRenewalPage({super.key, required this.contract});

  @override
  State<ContractRenewalPage> createState() => _ContractRenewalPageState();
}

class _ContractRenewalPageState extends State<ContractRenewalPage> {
  DateTime? _newEndDate;
  final dateFormat = DateFormat('dd/MM/yyyy');
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  int get _additionalDays {
    if (_newEndDate == null) return 0;
    // Calculate difference in days safely without time part
    final currentEnd = DateTime(
      widget.contract.returnDate.year,
      widget.contract.returnDate.month,
      widget.contract.returnDate.day,
    );
    final newEnd = DateTime(
      _newEndDate!.year,
      _newEndDate!.month,
      _newEndDate!.day,
    );
    return newEnd.difference(currentEnd).inDays;
  }

  void _selectQuickDays(int days) {
    setState(() {
      _newEndDate = widget.contract.returnDate.add(Duration(days: days));
    });
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _newEndDate ?? widget.contract.returnDate.add(const Duration(days: 1));
    final DateTime firstDate = widget.contract.returnDate.add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Preserve time from original return date if needed, or just use date
      setState(() {
        _newEndDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          widget.contract.returnDate.hour,
          widget.contract.returnDate.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedDate = _newEndDate != null && _additionalDays > 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const AppText(
          'Gia Hạn Hợp Đồng',
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContractTrackingSummaryCard(
                    contract: widget.contract,
                    status: ContractTrackingStatus.renting,
                  ),
                  const SizedBox(height: 16),
                  _buildCurrentRentalInfo(),
                  const SizedBox(height: 16),
                  _buildDateSelection(),
                  const SizedBox(height: 16),
                  _buildAvailabilityStatus(hasSelectedDate),
                  const SizedBox(height: 16),
                  _buildCostEstimation(hasSelectedDate),
                  const SizedBox(height: 16),
                  _buildPolicyNotice(),
                ],
              ),
            ),
          ),
          _buildBottomActionBar(hasSelectedDate),
        ],
      ),
    );
  }

  Widget _buildCurrentRentalInfo() {
    return _buildSectionCard(
      title: 'Thông tin thuê hiện tại',
      child: Column(
        children: [
          _buildInfoRow('Ngày nhận máy', dateFormat.format(widget.contract.pickupDate)),
          const SizedBox(height: 8),
          _buildInfoRow('Ngày trả hiện tại', dateFormat.format(widget.contract.returnDate), isHighlight: true),
          const SizedBox(height: 8),
          _buildInfoRow('Số ngày thuê', '${widget.contract.rentalDays} ngày'),
          const SizedBox(height: 8),
          _buildInfoRow('Đơn giá thuê/ngày', currencyFormat.format(widget.contract.pricePerDay)),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return _buildSectionCard(
      title: 'Chọn ngày trả mới',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Chọn ngày trả mới sau ngày trả hiện tại (${dateFormat.format(widget.contract.returnDate)})',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      _newEndDate != null ? dateFormat.format(_newEndDate!) : 'Chọn ngày...',
                      fontSize: 15,
                      fontWeight: _newEndDate != null ? FontWeight.w600 : FontWeight.normal,
                      color: _newEndDate != null 
                          ? Theme.of(context).colorScheme.onSurface 
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickSelectBtn(1),
              _buildQuickSelectBtn(2),
              _buildQuickSelectBtn(3),
              _buildQuickSelectBtn(5),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickSelectBtn(int days) {
    final isSelected = _additionalDays == days;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: days != 5 ? 8.0 : 0),
        child: InkWell(
          onTap: () => _selectQuickDays(days),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppText(
              '+$days ngày',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityStatus(bool hasSelectedDate) {
    return _buildSectionCard(
      title: 'Tình trạng khả dụng',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasSelectedDate ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSelectedDate ? Icons.pending_actions : Icons.info_outline, 
              color: hasSelectedDate ? Colors.amber.shade700 : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  hasSelectedDate ? 'Chưa kiểm tra lịch' : 'Vui lòng chọn ngày',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: hasSelectedDate ? Colors.amber.shade800 : Colors.grey.shade700,
                ),
                const SizedBox(height: 2),
                AppText(
                  hasSelectedDate 
                    ? 'Hệ thống cần kiểm tra xem thiết bị có bị trùng lịch thuê khác không.'
                    : 'Chọn ngày gia hạn để kiểm tra khả dụng',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostEstimation(bool hasSelectedDate) {
    return _buildSectionCard(
      title: 'Chi phí gia hạn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Thời gian gia hạn', hasSelectedDate ? '$_additionalDays ngày' : '---'),
          const SizedBox(height: 8),
          _buildInfoRow('Chi phí dự kiến', hasSelectedDate ? 'Đang chờ API...' : '---'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText('Tổng phí gia hạn', fontWeight: FontWeight.bold),
              AppText(
                hasSelectedDate ? 'Đang chờ API...' : '--- ₫',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'Chi phí chính thức sẽ được xác nhận ở bước thanh toán.',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.policy_outlined, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              AppText(
                'CHÍNH SÁCH GIA HẠN',
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBulletItem('Gia hạn thành công khi thanh toán hoàn tất và không trùng lịch khách khác.', Colors.blue.shade700),
          const SizedBox(height: 8),
          _buildBulletItem('Nên yêu cầu gia hạn trước 24h so với hạn trả để đảm bảo thiết bị còn trống.', Colors.blue.shade700),
        ],
      ),
    );
  }
  
  Widget _buildBulletItem(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6.0, right: 8.0, left: 4.0),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        Expanded(child: AppText(text, color: color.withValues(alpha: 0.9), fontSize: 13)),
      ],
    );
  }

  Widget _buildBottomActionBar(bool hasSelectedDate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Phí gia hạn',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  AppText(
                    hasSelectedDate ? 'Chờ tính...' : '--- ₫',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 140,
              child: PrimaryButton(
                onPressed: hasSelectedDate
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đang phát triển: Gọi API kiểm tra lịch & tính phí')),
                        );
                      }
                    : null,
                text: 'Tiếp tục',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, fontWeight: FontWeight.bold, fontSize: 16),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(
          label,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        AppText(
          value,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          color: isHighlight ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
        ),
      ],
    );
  }
}
