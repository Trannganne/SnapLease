import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/constants/app_sizes.dart';
import 'widgets/contract_handover_card.dart';
import 'tracking/bloc/contract_tracking_state.dart';
import 'tracking/widgets/contract_status_steps.dart';
import 'tracking/widgets/contract_tracking_summary_card.dart';
import 'tracking/widgets/current_contract_status_card.dart';
import 'tracking/widgets/contract_progress_timeline.dart';
import 'tracking/models/contract_tracking_view_data.dart';
import 'widgets/contract_section_card.dart';
import 'widgets/contract_payment_card.dart';
import '../../branches/presentation/branch_map_card.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../services/contract_pdf_service.dart';
import '../data/repositories/contract_repository.dart';
import '../data/repositories/contract_document_repository.dart';
import 'bloc/contract_detail_cubit.dart';
import 'bloc/contract_document_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../rental/bloc/rental_bloc.dart';
import 'renewal/contract_renewal_page.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';
import '../../review/presentation/widgets/review_device_picker.dart';
import '../domain/models/rental_terms.dart';
import '../../../core/navigation/app_route_observer.dart';
import 'widgets/contract_extension_card.dart';
import 'widgets/contract_settlement_card.dart';

class ContractPage extends StatefulWidget {
  final String contractId;
  final String? action;
  final String? appendixId;
  final ContractRepository? repository;
  final ContractDocumentRepository? documentRepository;

  const ContractPage({
    super.key,
    required this.contractId,
    this.action,
    this.appendixId,
    this.repository,
    this.documentRepository,
  });

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  bool isContractAccepted = false;
  ContractModel? contract;
  bool isLoading = true;
  String? errorMessage;
  bool hasPendingPayment = false;
  bool hasSuccessPayment = false;
  String _cancellationDraft = '';
  bool _requestingCancellation = false;

  late ContractDetailCubit _detailCubit;
  late ContractDocumentCubit _documents;
  StreamSubscription<ContractDetailState>? _detailSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _documents = ContractDocumentCubit(
      widget.documentRepository ?? ContractDocumentRepository(),
    );
    _createLoader();
  }

  void _createLoader() {
    _detailCubit = ContractDetailCubit(
      contractId: widget.contractId,
      repository: widget.repository ?? ContractRepository(),
    );
    _detailSubscription = _detailCubit.stream.listen((state) {
      if (!mounted) return;
      setState(() {
        contract = state.data?.contract;
        hasPendingPayment = state.data?.hasPendingDeposit ?? false;
        hasSuccessPayment = state.data?.hasSuccessfulDeposit ?? false;
        isLoading = state.loading && state.data == null;
        errorMessage = state.error;
      });
    });
    _loadContract();
  }

  Future<void> _loadContract() => _detailCubit.load();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    if (widget.action != 'renewal') _loadContract();
  }

  @override
  void didUpdateWidget(covariant ContractPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contractId != widget.contractId ||
        oldWidget.documentRepository != widget.documentRepository) {
      _documents.close();
      _documents = ContractDocumentCubit(
        widget.documentRepository ?? ContractDocumentRepository(),
      );
    }
    if (oldWidget.contractId != widget.contractId ||
        oldWidget.repository != widget.repository) {
      _detailSubscription?.cancel();
      _detailCubit.close();
      contract = null;
      isLoading = true;
      errorMessage = null;
      isContractAccepted = false;
      _createLoader();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _loadContract();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _detailSubscription?.cancel();
    _detailCubit.close();
    _documents.close();
    super.dispose();
  }

  void _copyContractId() {
    Clipboard.setData(ClipboardData(text: contract!.contractId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép mã hợp đồng')));
  }

  void _handleBack() {
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/?tab=contracts');
      }
    }
  }

  Future<void> _openTracking() async {
    await context.push('/contract/tracking', extra: contract!);
    if (mounted) await _loadContract();
  }

  void _openPreview() {
    context.push('/contract/preview', extra: contract!);
  }

  bool _sharingPdf = false;
  String? _sharingPdfContractId;

  Future<void> _sharePdf() async {
    if (_sharingPdf) return;
    setState(() {
      _sharingPdf = true;
      _sharingPdfContractId = widget.contractId;
    });
    try {
      final selected = contract!;
      final pdfData = await _documents.load(selected);
      if (!mounted ||
          contract?.contractId != selected.contractId ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      await Printing.sharePdf(
        bytes: pdfData,
        filename: '${selected.contractId}.pdf',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  Future<void> _continueContract() async {
    await context.push(
      contract!.status == 'DA_KY' ? '/payment' : '/signature',
      extra: contract!,
    );
    if (mounted) await _loadContract();
  }

  Future<void> _confirmCancellation() async {
    if (contract?.status != 'CHO_KY') {
      if (_requestingCancellation) return;
      final reason = TextEditingController(text: _cancellationDraft);
      final accepted = await showDialog<bool>(
        context: context,
        builder:
            (dialog) => AlertDialog(
              title: const Text('Yêu cầu hủy trước bàn giao'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cửa hàng sẽ duyệt nếu chưa bàn giao. Khấu trừ 0%/30%/100% tiền cọc đã thu theo mốc 48/24 giờ tại lúc gửi. Khoản phải hoàn được theo dõi riêng, chưa có nghĩa đã chuyển hoàn.',
                    ),
                    TextField(
                      controller: reason,
                      maxLength: 500,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Lý do hủy'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(false),
                  child: const Text('Đóng'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(true),
                  child: const Text('Gửi yêu cầu'),
                ),
              ],
            ),
      );
      final text = reason.text.trim();
      _cancellationDraft = reason.text;
      reason.dispose();
      if (accepted != true || text.isEmpty || !mounted) return;
      setState(() => _requestingCancellation = true);
      try {
        await _detailCubit.requestCancellation(text);
        _cancellationDraft = '';
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      } finally {
        if (mounted) setState(() => _requestingCancellation = false);
      }
      return;
    }
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const AppText('Hủy hợp đồng', fontWeight: FontWeight.bold),
            content: const AppText(
              'Bạn có chắc muốn hủy hợp đồng đang chờ ký này? Lượt giữ chỗ cũng sẽ bị hủy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const AppText('Đóng'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const AppText('Hủy', color: Colors.red),
              ),
            ],
          ),
    );
    if (shouldCancel != true || !mounted) return;
    try {
      setState(() => isLoading = true);
      await _detailCubit.cancelContract();
      if (!mounted) return;
      context.read<RentalBloc>().add(const ClearRentalSession());
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  bool get _documentAvailable =>
      contract != null &&
      (!contract!.requiresSignedPdf || contract!.signedPdfAvailable != false);

  Future<void> _navigateTo(String route) async {
    await context.push(route, extra: contract!);
    if (mounted) await _loadContract();
  }

  Future<void> _openReview() async {
    final selected = contract;
    if (selected?.status != 'HOAN_THANH') return;
    final devices =
        selected!.assignedDevices.where((x) => x.detailId.isNotEmpty).toList();
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có chi tiết thiết bị để đánh giá. Hãy tải lại hợp đồng.',
          ),
        ),
      );
      return;
    }
    final detailId =
        devices.length == 1
            ? devices.single.detailId
            : await showModalBottomSheet<String>(
              context: context,
              builder:
                  (sheet) => ReviewDevicePicker(
                    devices: devices,
                    models: selected.bookedDevices,
                    onSelected: (id) => Navigator.of(sheet).pop(id),
                  ),
            );
    if (!mounted ||
        detailId == null ||
        contract?.contractId != selected.contractId ||
        contract?.status != 'HOAN_THANH') {
      return;
    }
    await context.push('/review/${Uri.encodeComponent(detailId)}');
    if (mounted) await _loadContract();
  }

  String? get _primaryLabel => switch (contract?.status) {
    'CHO_BAN_GIAO' => 'Xem thanh toán',
    'DANG_THUE' => 'Gia hạn thuê',
    'CHO_HOAN_TRA' => 'Xem hợp đồng điện tử',
    'HOAN_THANH' => 'Đánh giá',
    'CHO_KY' => 'Ký và xác nhận',
    'DA_KY' =>
      hasSuccessPayment
          ? 'Xem thanh toán'
          : hasPendingPayment
          ? 'Xem yêu cầu thanh toán'
          : 'Tiếp tục thanh toán',
    _ => null,
  };

  VoidCallback? get _primaryAction => switch (contract?.status) {
    'HOAN_THANH' => _openReview,
    'CHO_BAN_GIAO' => () => _navigateTo('/payment'),
    'DANG_THUE' => () => _navigateTo('/contract/renewal'),
    'CHO_HOAN_TRA' => _documentAvailable ? _openPreview : null,
    'CHO_KY' => isContractAccepted ? _continueContract : null,
    'DA_KY' => _continueContract,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    if (!isLoading &&
        contract != null &&
        contract!.status != 'DA_HUY' &&
        widget.action == 'renewal') {
      return ContractRenewalPage(
        contract: contract!,
        repository: widget.repository,
        appendixId: widget.appendixId,
      );
    }
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colors.surface,
          leading: IconButton(
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const AppText(
            'Hợp đồng thuê',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          actions: [
            if ((contract?.status == 'CHO_KY' ||
                    (['DA_KY', 'CHO_BAN_GIAO'].contains(contract?.status) &&
                        contract?.termsVersion == RentalTerms.version &&
                        contract?.termsAccepted == true)) &&
                contract?.cancellations.any(
                      (x) => x['trangThai'] == 'CHO_XAC_NHAN',
                    ) !=
                    true)
              TextButton(
                onPressed: _confirmCancellation,
                child: AppText(
                  'Hủy',
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        body: SnapLoadingOverlay(
          loading:
              _requestingCancellation ||
              (_sharingPdf && _sharingPdfContractId == widget.contractId) ||
              (isLoading && contract != null),
          message:
              _requestingCancellation
                  ? 'Đang gửi yêu cầu hủy'
                  : _sharingPdf
                  ? 'Đang tải tài liệu hợp đồng'
                  : 'Đang xử lý hợp đồng thuê',
          avoidKeyboardInsets: false,
          child: SafeArea(top: false, child: _buildBody()),
        ),
        bottomNavigationBar:
            _primaryLabel == null
                ? null
                : AbsorbPointer(
                  absorbing: _sharingPdf || isLoading,
                  child: _buildActions(),
                ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && contract == null) {
      return const SnapLoadingView(
        message: 'Đang tải hợp đồng thuê',
        size: RetroCameraLoader.large,
      );
    }
    if (contract == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.spacingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: AppSizes.spacingM),
              AppText(
                errorMessage ?? 'Chưa tải được hợp đồng.',
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: _loadContract,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final current = contract!;
    final status = ContractTrackingState.parseStatus(current.status);
    final viewData = ContractTrackingViewData.fromContract(current, status);
    final sections = <Widget>[
      if (errorMessage != null) _notice(errorMessage!, isError: true),
      ContractStatusSteps(status: status),
      ContractTrackingSummaryCard(
        key: const ValueKey('contract-summary'),
        contract: current,
        status: status,
        showRentalDetails: true,
        onCopy: _copyContractId,
        onTrack: _openTracking,
      ),
      if (current.status == 'CHO_KY') ...[
        const VerificationProgress(currentStep: 4, totalSteps: 4),
        const ContractSectionCard(
          title: 'Kiểm tra hợp đồng thuê',
          icon: Icons.verified_user_outlined,
          child: AppText(
            'Vui lòng kiểm tra các thông tin quan trọng trước khi ký xác nhận trực tuyến.',
          ),
        ),
      ],
      CurrentContractStatusCard(viewData: viewData),
      if (current.latestExtension != null)
        ContractExtensionCard(
          extension: current.latestExtension!,
          effectiveReturn: current.effectiveReturnDate,
          onOpen:
              current.status == 'DA_HUY'
                  ? null
                  : () async {
                    await context.push(
                      Uri(
                        path: '/contract/${current.contractId}',
                        queryParameters: {
                          'action': 'renewal',
                          'appendixId': current.latestExtension!.id,
                        },
                      ).toString(),
                    );
                    if (mounted) await _loadContract();
                  },
          openLabel:
              current.latestExtension!.status == 'CHO_KY'
                  ? 'Xem và ký phụ lục'
                  : 'Xem kết quả gia hạn',
        ),
      if (current.cancellations.isNotEmpty)
        ContractSectionCard(
          title: 'Yêu cầu hủy và khoản phải hoàn',
          icon: Icons.receipt_long_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final request in current.cancellations)
                Text(
                  '${request['trangThai'] == 'CHO_XAC_NHAN'
                      ? 'Đang chờ duyệt hủy'
                      : request['trangThai'] == 'DA_DUYET'
                      ? 'Đã duyệt hủy'
                      : request['trangThai']}\nKhấu trừ: ${request['tienKhauTru']}đ\nCọc phải hoàn: ${request['tienCocPhaiHoan']}đ\nTiền thuê phải hoàn: ${request['tienThuePhaiHoan']}đ\nThu thừa phải hoàn đủ: ${request['tienThuThuaPhaiHoan'] ?? 0}đ',
                ),
              for (final refund in current.cancellationRefunds)
                Text(
                  '${refund['loaiThanhToan']}: ${refund['soTien']}đ — ${refund['trangThai'] == 'DA_HOAN' ? 'Đã xác nhận hoàn thực tế' : 'Đang theo dõi, chưa xác nhận hoàn'}',
                ),
            ],
          ),
        ),
      if (current.lateReturn?['apDungChinhSachMoi'] == true)
        ContractSectionCard(
          title: 'Tiền trả trễ',
          icon: Icons.schedule_outlined,
          child: Text(
            '${current.lateReturn!['laDuKien'] == true ? 'Dự kiến' : 'Theo thời điểm nhận thực tế'}: ${current.lateReturn!['tongTien']}đ\nTính riêng từng thiết bị theo đơn giá gốc; không miễn/giảm.',
          ),
        ),
      ContractProgressTimeline(
        title: 'Tiến trình hợp đồng',
        steps: viewData.timelineSteps,
      ),
      _buildPickup(),
      ContractHandoverCard(
        contract: current,
        repository: widget.repository,
        showSchedule: false,
      ),
      ContractPaymentCard(
        contract: current,
        onViewPayments: () => _navigateTo('/payment'),
      ),
      if (['DANG_THUE', 'CHO_HOAN_TRA', 'HOAN_THANH'].contains(current.status))
        ContractSettlementCard(
          devices: current.assignedDevices,
          settlement: _detailCubit.state.settlement,
          onOpen:
              () => context.push('/contract/${widget.contractId}/settlement'),
        ),
      _buildLegal(),
      _buildParties(),
      _buildNotices(),
      if (current.status == 'CHO_KY') _buildAcceptance(),
    ];
    return RefreshIndicator(
      onRefresh: _loadContract,
      child: SingleChildScrollView(
        key: const PageStorageKey('contract-detail-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pageMargin,
          AppSizes.spacingM,
          AppSizes.pageMargin,
          AppSizes.spacingL,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSizes.spacingM),
                  sections[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickup() {
    final current = contract!;
    final date = DateFormat('HH:mm • dd/MM/yyyy');
    return ContractSectionCard(
      title: 'Thông tin nhận / trả thiết bị',
      icon: Icons.place_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('Chi nhánh', current.branchName),
          const SizedBox(height: AppSizes.spacingM),
          BranchMapCard(
            key: ValueKey(current.branchId),
            branchId: current.branchId,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: 'Địa điểm nhận',
            value: _value(current.lessorAddress),
            icon: Icons.storefront_outlined,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: 'Nhận dự kiến',
            value: date.format(current.pickupDate),
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: 'Hạn trả',
            value: date.format(current.effectiveReturnDate),
            icon: Icons.event_outlined,
          ),
          if (current.lessorPhone.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spacingS),
            ContractInfoTile(
              label: 'Hotline chi nhánh',
              value: current.lessorPhone,
              icon: Icons.phone_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegal() {
    final current = contract!;
    final format = DateFormat('HH:mm • dd/MM/yyyy');
    final signed = current.requiresSignedPdf;
    final method = switch (current.signingMethod) {
      'DIEN_TU' => 'Ký điện tử',
      'BAN_GIAY' => 'Ký bản giấy',
      'MAN_HINH' => 'Ký trên màn hình',
      _ => _value(current.signingMethod ?? ''),
    };
    return ContractSectionCard(
      title: 'Pháp lý & xác thực',
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContractInfoTile(
            label: 'Hình thức ký',
            value: method,
            icon: Icons.draw_outlined,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: 'Thời điểm ký',
            value:
                current.signedAt == null
                    ? (signed
                        ? 'Chưa có thông tin thời điểm ký'
                        : 'Chưa ghi nhận thời điểm ký')
                    : format.format(current.signedAt!),
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: 'Điều khoản hợp đồng',
            value:
                '${switch (current.termsAccepted) {
                  true => 'Đã ghi nhận đồng ý điều khoản',
                  false => 'Chưa ghi nhận đồng ý điều khoản',
                  null => 'Chưa có thông tin đồng ý điều khoản',
                }}${current.termsVersion?.isNotEmpty == true ? '\nPhiên bản: ${current.termsVersion}' : ''}',
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(height: AppSizes.spacingS),
          ContractInfoTile(
            label: signed ? 'Bản hợp đồng đã ký' : 'Nội dung hợp đồng',
            value:
                _documentAvailable
                    ? (signed
                        ? 'Xem file PDF đã lưu của hợp đồng này'
                        : 'Chưa có bản hợp đồng đã ký')
                    : 'Chưa có bản hợp đồng đã ký',
            icon: Icons.picture_as_pdf_outlined,
            action: OutlinedButton.icon(
              key: const ValueKey('contract-preview'),
              onPressed: _documentAvailable ? _openPreview : null,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(
                signed ? 'Xem bản ký' : 'Xem nội dung hợp đồng',
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacingS),
          OutlinedButton.icon(
            key: const ValueKey('contract-download-pdf'),
            onPressed: _sharingPdf || !_documentAvailable ? null : _sharePdf,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(
              _sharingPdf ? 'Đang chuẩn bị PDF…' : 'Tải PDF',
              textAlign: TextAlign.center,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: AppSizes.spacingS),
          AppText(
            'Chưa có thông tin xác thực định danh.',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSizes.spacingS),
          AppText(
            'Bao gồm điều khoản bảo hiểm thiết bị, chính sách hoàn cọc và trách nhiệm bồi thường chi tiết.',
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildParties() => ContractSectionCard(
    title: 'Thông tin hợp đồng và các bên',
    icon: Icons.people_outline,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('Ngày lập', DateFormat('dd/MM/yyyy').format(contract!.date)),
        const Divider(height: AppSizes.spacingL),
        _party(
          'BÊN CHO THUÊ',
          Icons.storefront_outlined,
          contract!.lessorName,
          [
            _field('Địa chỉ', contract!.lessorAddress),
            _field('Hotline', contract!.lessorPhone),
          ],
        ),
        const SizedBox(height: AppSizes.spacingM),
        _party('BÊN THUÊ', Icons.person_outline, contract!.lesseeName, [
          _field('CCCD', contract!.lesseeId),
          _field('SĐT', contract!.lesseePhone),
        ]),
      ],
    ),
  );

  Widget _buildNotices() => ContractSectionCard(
    title: 'Lưu ý trong quá trình thuê',
    icon: Icons.warning_amber_outlined,
    tint: Theme.of(context).colorScheme.primary.withValues(alpha: .025),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tip('Khách hàng cần mang CCCD bản gốc khi nhận thiết bị.'),
        _tip(
          'Thiết bị sẽ được kiểm tra ngoại quan và chức năng khi bàn giao và hoàn trả.',
        ),
        _tip(
          'Tiền cọc được hoàn trả theo quy định điều khoản hợp đồng sau kiểm tra máy.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _documentAvailable ? _openPreview : null,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Xem toàn bộ'),
          ),
        ),
      ],
    ),
  );

  Widget _buildAcceptance() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        value: isContractAccepted,
        onChanged: (value) {
          if (value != null) setState(() => isContractAccepted = value);
        },
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Tôi đã kiểm tra các thông tin quan trọng và đồng ý với nội dung hợp đồng thuê.',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(height: AppSizes.spacingS),
              AppText(
                "Bạn có thể chọn 'Xem toàn bộ' để đọc đầy đủ điều khoản trước khi ký xác nhận.",
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  String _value(String value) =>
      value.trim().isEmpty ? 'Chưa có thông tin' : value;

  Widget _field(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        label,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(height: 4),
      AppText(_value(value), fontSize: 13, fontWeight: FontWeight.w500),
    ],
  );

  Widget _party(
    String title,
    IconData icon,
    String name,
    List<Widget> details,
  ) => ContractInfoTile(
    label: title,
    value: _value(name),
    icon: icon,
    action: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final detail in details) ...[
          const SizedBox(height: AppSizes.spacingS),
          detail,
        ],
      ],
    ),
  );

  Widget _notice(String text, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSizes.spacingS),
          Expanded(child: AppText(text, color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _tip(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacingS),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Icon(
            Icons.circle,
            size: 4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Expanded(child: AppText(text, fontSize: 13)),
      ],
    ),
  );

  Widget _buildActions() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: .45)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pageMargin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (contract!.status == 'HOAN_THANH') ...[
                AppText(
                  'Cảm ơn bạn đã lựa chọn SNAPLEASE!',
                  textAlign: TextAlign.center,
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSizes.spacingS),
              ],
              if (contract!.status == 'CHO_HOAN_TRA' &&
                  !_documentAvailable) ...[
                AppText(
                  'Chưa có bản hợp đồng đã ký',
                  textAlign: TextAlign.center,
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSizes.spacingS),
              ],
              ElevatedButton(
                key: const ValueKey('contract-primary-action'),
                onPressed: _primaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _primaryLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
