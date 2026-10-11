import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/app_image.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../services/contract_pdf_service.dart';
import '../data/repositories/contract_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../rental/bloc/rental_bloc.dart';
import 'renewal/contract_renewal_page.dart';

class ContractPage extends StatefulWidget {
  final String contractId;
  final String? action;
  
  const ContractPage({
    super.key,
    required this.contractId,
    this.action,
  });

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  bool isContractAccepted = false;
  ContractModel? contract;
  bool isLoading = true;
  String? errorMessage;
  bool hasPendingPayment = false;
  bool hasSuccessPayment = false;
  
  final ContractRepository _repository = ContractRepository();

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      final data = await _repository.getContractById(widget.contractId);
      final c = data;
      // Map API response to ContractModel
      final datTheoDongMayList = c['datTheoDongMay'] as List? ?? [];
      final chiTietList = c['chiTiet'] as List? ?? [];
      
      final Map<String, dynamic> datTheoDongMay = datTheoDongMayList.isNotEmpty ? datTheoDongMayList.first : {};
      final Map<String, dynamic> chiTiet = chiTietList.isNotEmpty ? chiTietList.first : {};
      
      final Map<String, dynamic> details = datTheoDongMay.isNotEmpty ? datTheoDongMay : chiTiet;

      final khach = c['khachThue'] ?? {};
      final chiNhanh = c['chiNhanh'] ?? {};
      
      final paymentsList = c['thanhToan'] as List? ?? [];
      final pendingPayment = paymentsList.any((p) => p['loaiThanhToan'] == 'TIEN_COC' && p['trangThai'] == 'CHO_THANH_TOAN');
      final successPayment = paymentsList.any((p) => p['loaiThanhToan'] == 'TIEN_COC' && p['trangThai'] == 'THANH_CONG');
      
      setState(() {
        hasPendingPayment = pendingPayment;
        hasSuccessPayment = successPayment;
        contract = ContractModel(
          contractId: c['maHopDong'] ?? widget.contractId,
          date: c['ngayTaoHopDong'] != null ? DateTime.parse(c['ngayTaoHopDong']) : DateTime.now(),
          lessorName: 'SNAPLEASE',
          lessorAddress: chiNhanh['diaChi'] ?? 'CN Snaplease',
          lessorPhone: chiNhanh['soDienThoai'] ?? '1900 1234',
          lesseeName: khach['hoTen'] ?? '',
          lesseeId: khach['cccd'] ?? '',
          lesseePhone: khach['soDienThoai'] ?? '',
          deviceName: details['tenDongMay'] ?? 'Thiết bị',
          deviceModel: details['tenDongMay'] ?? '',
          quantity: details['soLuong'] ?? 1,
          pricePerDay: (details['donGiaTieuChuan'] ?? 0).toInt(),
          pickupDate: details['ngayBatDau'] != null ? DateTime.parse(details['ngayBatDau']) : DateTime.now(),
          returnDate: details['ngayKetThuc'] != null ? DateTime.parse(details['ngayKetThuc']) : DateTime.now(),
          rentalDays: details['soNgayThue'] ?? 1,
          branchName: chiNhanh['tenCuaHang'] ?? 'Chi nhánh Snaplease',
          rentalTotal: (c['tongTien'] ?? 0).toInt(),
          deposit: (c['tongTienCoc'] ?? 0).toInt(),
          totalAmount: ((c['tongTien'] ?? 0) + (c['tongTienCoc'] ?? 0)).toInt(),
          status: c['trangThai'],
          deviceImageUrl: details['hinhAnh'],
        );
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void _copyContractId() {
    Clipboard.setData(ClipboardData(text: contract!.contractId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép mã hợp đồng')));
  }

  void _handleBack() {
    if (mounted) {
      context.pop();
    }
  }

  Map<String, dynamic> _getBadgeInfo(String? status) {
    if (status == 'DA_KY' && hasSuccessPayment) {
      return {'text': 'Chờ bàn giao', 'color': Colors.orange};
    }
    if (status == 'DA_KY' && hasPendingPayment) {
      return {'text': 'Chờ xác nhận thanh toán', 'color': Colors.orange};
    }
    
    switch (status) {
      case 'CHO_KY':
        return {'text': 'Chờ ký', 'color': Colors.orange};
      case 'DA_KY':
        return {'text': 'Chờ thanh toán', 'color': Colors.orange};
      case 'CHO_BAN_GIAO':
        return {'text': 'Chờ bàn giao', 'color': Colors.orange};
      case 'DANG_THUE':
        return {'text': 'Đang thuê', 'color': Colors.green};
      case 'HOAN_THANH':
        return {'text': 'Hoàn tất', 'color': Colors.blue};
      case 'DA_HUY':
        return {'text': 'Đã hủy', 'color': Colors.red};
      default:
        return {'text': 'Không rõ', 'color': Colors.grey};
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!isLoading && contract != null && widget.action == 'renewal') {
      return ContractRenewalPage(contract: contract!);
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );
    final dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _handleBack,
          ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'Hợp đồng thuê',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            if (contract != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (_getBadgeInfo(contract!.status)['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: AppText(
                  _getBadgeInfo(contract!.status)['text'] as String,
                  color: _getBadgeInfo(contract!.status)['color'] as Color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (contract?.status == 'CHO_KY')
            TextButton(
              onPressed: () async {
                final shouldCancel = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const AppText('Hủy hợp đồng', fontWeight: FontWeight.bold),
                    content: const AppText('Bạn có chắc muốn hủy hợp đồng đang chờ ký này? Lượt giữ chỗ cũng sẽ bị hủy.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const AppText('Đóng'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const AppText('Hủy', color: Colors.red),
                      ),
                    ],
                  ),
                );
                
                if (shouldCancel == true) {
                  try {
                    setState(() => isLoading = true);
                    await _repository.cancelContract(widget.contractId);
                    if (!context.mounted) return;
                    context.read<RentalBloc>().add(const ClearRentalSession());
                    context.pop();
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const AppText('Hủy', color: Colors.red, fontWeight: FontWeight.bold),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: UserAvatar(displayName: 'Tuan', radius: 16, onTap: () {}),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        AppText(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContract,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : contract == null
                  ? const SizedBox()
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contract!.status == 'CHO_KY') ...[
                    const VerificationProgress(currentStep: 4, totalSteps: 4),
                    const SizedBox(height: 24),
                    // Guidance Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText(
                                  'Kiểm tra hợp đồng thuê',
                                  fontWeight: FontWeight.bold,
                                ),
                                const SizedBox(height: 4),
                                AppText(
                                  'Vui lòng kiểm tra các thông tin quan trọng trước khi ký xác nhận trực tuyến.',
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Contract Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText(
                        'Thông tin hợp đồng',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (_getBadgeInfo(contract!.status)['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: AppText(
                          _getBadgeInfo(contract!.status)['text'] as String,
                          color: _getBadgeInfo(contract!.status)['color'] as Color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppText(
                                'Mã hợp đồng:',
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: AppText(
                                      contract!.contractId,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: _copyContractId,
                                    child: Icon(
                                      Icons.copy,
                                      size: 14,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Ngày lập:',
                          dateFormatter.format(contract!.date),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Chi nhánh lập:',
                          'SNAPLEASE Quận 1, TP.HCM',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Parties Info
                  const AppText(
                    'Thông tin các bên',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPartyCard(
                          'BÊN CHO THUÊ',
                          contract!.lessorName,
                          [
                            'Địa chỉ:\n${contract!.lessorAddress}',
                            'Hotline: ${contract!.lessorPhone}',
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            _buildPartyCard('BÊN THUÊ', contract!.lesseeName, [
                              'CCCD:\n${contract!.lesseeId}',
                              'SĐT:\n${contract!.lesseePhone}',
                            ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Device
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText(
                        'Thiết bị thuê',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      AppText(
                        '1 mục',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Center(
                                child: AppImage(
                                  imageUrl: contract!.deviceImageUrl ?? '',
                                  width: 32,
                                  iconSize: 24,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    contract!.deviceName,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  AppText(
                                    contract!.deviceModel,
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: 4),
                                  AppText(
                                    'Số lượng: ${contract!.quantity}',
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                            AppText(
                              '${currencyFormatter.format(contract!.pricePerDay)} / ngày',
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppText(
                                'Thời gian thuê:',
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: AppText(
                                '${dateFormatter.format(contract!.pickupDate)} → ${dateFormatter.format(contract!.returnDate)} (${contract!.rentalDays} ngày)',
                                textAlign: TextAlign.right,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppText(
                                'Địa điểm nhận/trả:',
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: AppText(
                                contract!.branchName,
                                textAlign: TextAlign.right,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cost
                  const AppText(
                    'Chi phí',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Tiền thuê (${contract!.rentalDays} ngày)',
                          currencyFormatter.format(contract!.rentalTotal),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Tiền cọc thiết bị',
                          currencyFormatter.format(contract!.deposit),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppText(
                              'Tổng dự kiến',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            AppText(
                              currencyFormatter.format(contract!.totalAmount),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                '* Bao gồm tiền thuê và cọc hoàn trả',
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Important Notes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText(
                        'Lưu ý quan trọng',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      InkWell(
                        onTap: () {
                          context.push('/contract/preview', extra: contract);
                        },
                        child: AppText(
                          'Xem toàn bộ →',
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildTipBullet(
                          'Khách hàng cần mang CCCD bản gốc khi nhận thiết bị.',
                        ),
                        _buildTipBullet(
                          'Thiết bị sẽ được kiểm tra ngoại quan và chức năng khi bàn giao và hoàn trả.',
                        ),
                        _buildTipBullet(
                          'Tiền cọc được hoàn trả theo quy định điều khoản hợp đồng sau kiểm tra máy.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PDF Action Card
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Xem toàn bộ nội dung hợp đồng',
                          fontWeight: FontWeight.bold,
                        ),
                        SizedBox(height: 8),
                        AppText(
                          'Bao gồm điều khoản bảo hiểm thiết bị, chính sách hoàn cọc và trách nhiệm bồi thường chi tiết.',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  context.push(
                                    '/contract/preview',
                                    extra: contract,
                                  );
                                },
                                child: const AppText('Xem chi tiết', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final pdfService = ContractPdfService();
                                  final pdfData = await pdfService
                                      .generateContractPdf(contract!);
                                  await Printing.sharePdf(
                                    bytes: pdfData,
                                    filename: '${contract!.contractId}.pdf',
                                  );
                                },
                                icon: const Icon(Icons.download, size: 18),
                                label: const AppText('Tải PDF', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Checkbox
                  if (contract!.status == 'CHO_KY')
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isContractAccepted,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                isContractAccepted = value;
                              });
                            }
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppText(
                              'Tôi đã kiểm tra các thông tin quan trọng và đồng ý với nội dung hợp đồng thuê.',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            SizedBox(height: 4),
                            AppText(
                              "Bạn có thể chọn 'Xem toàn bộ' để đọc đầy đủ điều khoản trước khi ký xác nhận.",
                              fontSize: 11,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          if (contract != null && (contract!.status == 'CHO_KY' || contract!.status == 'DA_KY'))
            Container(
              padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        'Tổng dự kiến',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      AppText(
                        currencyFormatter.format(contract!.totalAmount),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    context.push('/contract/preview', extra: contract!);
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: PrimaryButton(
                    text: contract!.status == 'DA_KY'
                        ? (hasSuccessPayment
                            ? 'Xem thanh toán'
                            : (hasPendingPayment ? 'Xem yêu cầu thanh toán' : 'Tiếp tục thanh toán'))
                        : 'Ký và xác nhận',
                    onPressed: contract!.status == 'DA_KY'
                        ? () {
                            // If hasSuccessPayment, might go to payment success or just payment page to view
                            context.push('/payment', extra: contract!);
                          }
                        : isContractAccepted
                            ? () {
                                context.push('/signature', extra: contract!);
                              }
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
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
            fontWeight: FontWeight.w500,
            fontSize: 13,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildPartyCard(String title, String name, List<String> details) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: 4),
          AppText(name, fontWeight: FontWeight.bold, fontSize: 13),
          const SizedBox(height: 8),
          ...details.map(
            (detail) => Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: AppText(
                detail,
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, size: 6, color: Colors.orange),
          ),
          Expanded(
            child: AppText(
              text,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
