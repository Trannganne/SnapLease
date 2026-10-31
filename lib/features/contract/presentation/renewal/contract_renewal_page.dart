import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'contract_renewal_cubit.dart';
import '../../data/repositories/contract_repository.dart';
import '../../../../core/widgets/app_availability_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/snap_loading_view.dart';
import '../../../../core/widgets/retro_camera_loader.dart';
import '../../services/contract_pdf_service.dart';
import '../tracking/bloc/contract_tracking_state.dart';
import '../tracking/widgets/contract_tracking_summary_card.dart';
import '../../data/repositories/appendix_signing_repository.dart';
import '../bloc/contract_signing_cubit.dart';
import '../bloc/contract_signing_state.dart';
import '../widgets/otp_verification_dialog.dart';
import '../../domain/models/extension_models.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../widgets/contract_extension_card.dart';

class ContractRenewalPage extends StatefulWidget {
  final ContractModel contract;
  final ContractRepository? repository;
  final String? appendixId;

  const ContractRenewalPage({
    super.key,
    required this.contract,
    this.repository,
    this.appendixId,
  });

  @override
  State<ContractRenewalPage> createState() => _ContractRenewalPageState();
}

class _ContractRenewalPageState extends State<ContractRenewalPage>
    with WidgetsBindingObserver, RouteAware {
  ModalRoute<dynamic>? _route;
  late ContractRenewalCubit _cubit;
  final _reason = TextEditingController();
  ContractRenewalState get _state => _cubit.state;
  ContractModel get _contract => _state.contract ?? widget.contract;
  DateTime get _currentReturn => _state.currentReturn ?? _contract.returnDate;
  DateTime? get _newEndDate => _state.selected;
  bool _preparingSignature = false;
  Future<void> _signAppendix() async {
    if (_preparingSignature) return;
    setState(() => _preparingSignature = true);
    try {
      await _cubit.load();
      if (!mounted) return;
      var row = _state.selectedAppendix;
      if (!_state.canSign || row == null) {
        throw StateError(
          'Phụ lục không còn đủ điều kiện ký. Hãy kiểm tra trạng thái và hạn ký mới nhất.',
        );
      }
      final id = row['maPhuLuc'] as String;
      final bytes = await _cubit.repository.loadAppendixPdf(id);
      if (!mounted) return;
      await context.push('/contract/appendix/$id/pdf', extra: _contract);
      if (!mounted) return;
      await _cubit.load();
      row = _state.selectedAppendix;
      if (!mounted || !_state.canSign || row?['maPhuLuc'] != id) {
        throw StateError(
          'Phụ lục đã hết hạn ký hoặc trạng thái thay đổi; không yêu cầu OTP.',
        );
      }
      final reviewedRow = row!;
      final clauses = appendixTermsText(reviewedRow);
      final accepted = await showDialog<bool>(
        context: context,
        builder:
            (dialog) => AlertDialog(
              title: const Text('Đồng ý phụ lục gia hạn'),
              content: SingleChildScrollView(
                child: Text(
                  'Hạn mới: ${reviewedRow['thoiHanTraMoi']}\nPhí: ${reviewedRow['chiPhiPhatSinh']}đ, quyết toán khi trả máy.\n\n$clauses',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(false),
                  child: const Text('Đóng'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(true),
                  child: const Text('Đồng ý và nhận OTP'),
                ),
              ],
            ),
      );
      if (accepted != true || !mounted) return;
      await _cubit.load();
      if (!mounted ||
          !_state.canSign ||
          _state.selectedAppendix?['maPhuLuc'] != id) {
        throw StateError(
          'Phụ lục đã hết hạn ký hoặc trạng thái thay đổi; không yêu cầu OTP.',
        );
      }
      final signing = ContractSigningCubit(AppendixSigningRepository(id));
      await signing.requestOtp(_contract, bytes, true);
      if (!mounted) {
        await signing.close();
        return;
      }
      final sent = signing.state;
      if (sent is! ContractSigningOtpSent) {
        final failure =
            sent is ContractSigningFailure ? sent.error : 'Chưa gửi được OTP.';
        await signing.close();
        throw StateError(failure);
      }
      await showDialog<void>(
        context: context,
        builder:
            (dialog) => BlocProvider.value(
              value: signing,
              child: BlocListener<ContractSigningCubit, ContractSigningState>(
                listener: (ctx, state) {
                  if (state is ContractSigningSuccess) Navigator.of(ctx).pop();
                  if (state is ContractSigningFailure) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.error)));
                  }
                },
                child: OtpVerificationDialog(
                  contract: _contract,
                  maXacNhan: sent.maXacNhan,
                  emailMask: sent.emailMask,
                  expiredAt: sent.expiredAt,
                  daDongYDieuKhoan: true,
                ),
              ),
            ),
      );
      await signing.close();
      await _cubit.load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _preparingSignature = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = ContractRenewalCubit(
      widget.contract.contractId,
      widget.repository ?? ContractRepository(),
      appendixId: widget.appendixId,
    )..load();
    _reason.addListener(_reasonChanged);
  }

  void _reasonChanged() => setState(() {});

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
  void didPopNext() => _cubit.load();

  @override
  void didUpdateWidget(covariant ContractRenewalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contract.contractId != widget.contract.contractId ||
        oldWidget.repository != widget.repository ||
        oldWidget.appendixId != widget.appendixId) {
      _cubit.close();
      _cubit = ContractRenewalCubit(
        widget.contract.contractId,
        widget.repository ?? ContractRepository(),
        appendixId: widget.appendixId,
      )..load();
      _reason.clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _cubit.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _reason.dispose();
    _cubit.close();
    super.dispose();
  }

  final dateFormat = DateFormat('dd/MM/yyyy');
  final currencyFormat = const AppMoneyFormatter();

  int get _additionalDays => _state.quote?.days ?? 0;
  String _deadline(Object value) => DateFormat('dd/MM/yyyy HH:mm').format(
    DateTime.parse(value.toString()).toUtc().add(const Duration(hours: 7)),
  );
  void _selectQuickDays(int days) =>
      _cubit.selectDate(_currentReturn.add(Duration(days: days)));
  Future<void> _selectDate() async {
    if (!_state.canSelect) return;
    final result = await AppAvailabilityCalendar.show(
      context,
      currentPickup: _currentReturn,
      currentReturn: _newEndDate,
      branchId: null,
      deviceId: '',
      quantity: 1,
      fixedPickup: true,
    );
    if (result != null && mounted) await _cubit.selectDate(result['return']!);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContractRenewalCubit, ContractRenewalState>(
      bloc: _cubit,
      builder: (context, state) {
        final hasSelectedDate = state.quote?.available == true;

        return PopScope(
          canPop: !state.submitting,
          child: SnapLoadingOverlay(
            loading: state.submitting || _preparingSignature,
            message: 'Đang xử lý yêu cầu gia hạn',
            child: Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: state.submitting ? null : () => context.pop(),
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
              body:
                  state.loading && state.contract == null
                      ? const SnapLoadingView(
                        message: 'Đang tải thông tin gia hạn',
                        size: RetroCameraLoader.large,
                      )
                      : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ContractTrackingSummaryCard(
                                    contract: _contract,
                                    status: ContractTrackingState.parseStatus(
                                      _contract.status,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if ((state.loading &&
                                          state.contract != null) ||
                                      state.previewing)
                                    const SnapLoadingProgress(
                                      label: 'Đang cập nhật thông tin gia hạn',
                                    ),
                                  if (state.message != null)
                                    AppText(state.message!),
                                  if (state.selectedAppendix != null)
                                    ContractExtensionCard(
                                      extension: ExtensionSummary.fromJson(
                                        state.selectedAppendix!,
                                      ),
                                      effectiveReturn: _currentReturn,
                                    ),
                                  if (state.selectedAppendix?['hanXuLyUtc'] !=
                                          null &&
                                      state.selectedAppendix?['trangThai'] ==
                                          'CHO_XAC_NHAN')
                                    AppText(
                                      'Hạn xử lý: ${_deadline(state.selectedAppendix!['hanXuLyUtc'])} (giờ Việt Nam)',
                                    ),
                                  for (final row in _contract.extensions.where(
                                    (r) =>
                                        r['maPhuLuc'] !=
                                        state.selectedAppendix?['maPhuLuc'],
                                  ))
                                    ContractExtensionCard(
                                      extension: ExtensionSummary.fromJson(row),
                                      effectiveReturn: _currentReturn,
                                      onOpen:
                                          row['maPhuLuc'] is String
                                              ? () async {
                                                await context.push(
                                                  Uri(
                                                    path:
                                                        '/contract/${_contract.contractId}',
                                                    queryParameters: {
                                                      'action': 'renewal',
                                                      'appendixId':
                                                          row['maPhuLuc']
                                                              as String,
                                                    },
                                                  ).toString(),
                                                );
                                                if (mounted) {
                                                  await _cubit.load();
                                                }
                                              }
                                              : null,
                                    ),
                                  if (state.selectedAppendix?['trangThai'] ==
                                      'CHO_KY')
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: PrimaryButton(
                                        text: 'Xem và ký phụ lục',
                                        onPressed:
                                            _preparingSignature ||
                                                    !state.canSign
                                                ? null
                                                : _signAppendix,
                                      ),
                                    ),
                                  TextButton(
                                    onPressed:
                                        state.loading || state.submitting
                                            ? null
                                            : () => _cubit.load(),
                                    child: const Text('Tải lại hợp đồng'),
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentRentalInfo() {
    return _buildSectionCard(
      title: 'Thông tin thuê hiện tại',
      child: Column(
        children: [
          _buildInfoRow(
            'Ngày nhận máy',
            dateFormat.format(_contract.pickupDate),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Ngày trả hiện tại',
            dateFormat.format(_currentReturn),
            isHighlight: true,
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Số ngày thuê', '${_contract.rentalDays} ngày'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Đơn giá thuê/ngày',
            _contract.bookedDevices.length > 1
                ? 'Theo báo giá gia hạn'
                : currencyFormat.format(_contract.pricePerDay),
          ),
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
            'Chọn ngày trả mới sau ngày trả hiện tại (${dateFormat.format(_currentReturn)})',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _state.canSelect ? _selectDate : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppText(
                      _newEndDate != null
                          ? dateFormat.format(_newEndDate!)
                          : 'Chọn ngày...',
                      fontSize: 15,
                      fontWeight:
                          _newEndDate != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                      color:
                          _newEndDate != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            enabled: _state.canSelect,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Lý do gia hạn',
              border: OutlineInputBorder(),
            ),
          ),
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
          onTap: _state.canSelect ? () => _selectQuickDays(days) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
              border: Border.all(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: AppText(
              '+$days ngày',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
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
              color:
                  hasSelectedDate
                      ? Colors.amber.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
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
                  _state.previewing
                      ? 'Đang kiểm tra lịch...'
                      : _state.quote?.available == true
                      ? 'Có thể gửi yêu cầu'
                      : 'Chưa có dự kiến hợp lệ',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color:
                      hasSelectedDate
                          ? Colors.amber.shade800
                          : Colors.grey.shade700,
                ),
                const SizedBox(height: 2),
                AppText(
                  hasSelectedDate
                      ? (_state.quote?.reason ??
                          'Backend kiểm tra toàn bộ khoảng gia hạn của hợp đồng.')
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
          _buildInfoRow(
            'Thời gian gia hạn',
            hasSelectedDate ? '$_additionalDays ngày' : '---',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Chi phí dự kiến',
            hasSelectedDate ? currencyFormat.format(_state.quote!.cost) : '---',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppText('Tổng phí gia hạn', fontWeight: FontWeight.bold),
              AppText(
                hasSelectedDate
                    ? currencyFormat.format(_state.quote!.cost)
                    : '--- ₫',
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
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    'Chi phí dự kiến do hệ thống tính; yêu cầu cần cửa hàng xác nhận.',
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
              Icon(
                Icons.policy_outlined,
                color: Colors.blue.shade700,
                size: 20,
              ),
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
          _buildBulletItem(
            'Chỉ gửi khi đang thuê và còn ít nhất 24 giờ. Hạn mới chỉ có hiệu lực sau khi cửa hàng duyệt và bạn ký phụ lục thành công.',
            Colors.blue.shade700,
          ),
          const SizedBox(height: 8),
          _buildBulletItem(
            'Xử lý trong 4 giờ làm việc, không muộn hơn hạn hiện tại trừ 2 giờ. Sau duyệt có tối đa 2 giờ liên tục để ký và không vượt hạn hiện tại; phí theo đơn giá gốc, quyết toán khi trả máy.',
            Colors.blue.shade700,
          ),
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
        Expanded(
          child: AppText(
            text,
            color: color.withValues(alpha: 0.9),
            fontSize: 13,
          ),
        ),
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
                    hasSelectedDate
                        ? currencyFormat.format(_state.quote!.cost)
                        : '--- ₫',
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
                isLoading: _state.submitting,
                showLoadingAnimation: false,
                onPressed:
                    _state.canSubmit &&
                            _reason.text.trim().isNotEmpty &&
                            _reason.text.trim().length <= 500
                        ? () => _cubit.submit(_reason.text)
                        : null,
                text: _state.submitting ? 'Đang gửi...' : 'Gửi yêu cầu',
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
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
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
          color:
              isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
        ),
      ],
    );
  }
}
