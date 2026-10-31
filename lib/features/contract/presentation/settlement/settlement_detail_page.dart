import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentcam/core/constants/app_sizes.dart';
import 'package:rentcam/core/formatters/app_money_formatter.dart';
import 'package:rentcam/core/navigation/app_route_observer.dart';
import 'package:rentcam/core/widgets/app_text.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import '../../data/repositories/contract_repository.dart';
import '../../domain/models/handover_models.dart';
import '../../domain/models/settlement_view.dart';
import '../bloc/contract_detail_cubit.dart';
import '../tracking/models/contract_timeline_step.dart';
import '../tracking/widgets/contract_progress_timeline.dart';
import '../widgets/contract_section_card.dart';
import '../../../review/presentation/widgets/review_device_picker.dart';

class SettlementDetailPage extends StatefulWidget {
  final String contractId;
  final ContractRepository? repository;
  const SettlementDetailPage({
    super.key,
    required this.contractId,
    this.repository,
  });
  @override
  State<SettlementDetailPage> createState() => _SettlementDetailPageState();
}

class _SettlementDetailPageState extends State<SettlementDetailPage>
    with WidgetsBindingObserver, RouteAware {
  late ContractDetailCubit _cubit;
  ModalRoute<dynamic>? _route;
  final _images = <String, Future<List<int>>>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  void _create() {
    _cubit = ContractDetailCubit(
      contractId: widget.contractId,
      repository: widget.repository ?? ContractRepository(),
      settlementOnly: true,
    )..load();
  }

  @override
  void didUpdateWidget(covariant SettlementDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contractId != widget.contractId ||
        oldWidget.repository != widget.repository) {
      _cubit.close();
      _images.clear();
      _create();
    }
  }

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      _cubit.load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _cubit.close();
    super.dispose();
  }

  String _money(num? value) =>
      value == null
          ? 'Chưa xác định'
          : '${NumberFormat('#,##0.##', 'vi_VN').format(value)}đ';
  String? _date(dynamic value, {bool utc = false}) {
    var date = apiDate(value);
    if (date == null) return null;
    // SQL DateTime fields may omit the suffix. UTC-named fields still represent
    // UTC; actual receipt/payment timestamps use the existing local-time API.
    if (utc && !date.isUtc) {
      date = DateTime.utc(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
        date.millisecond,
        date.microsecond,
      );
    }
    return DateFormat(
      'HH:mm • dd/MM/yyyy',
    ).format(date.isUtc ? date.add(const Duration(hours: 7)) : date);
  }

  String _method(dynamic value, [dynamic provider]) => switch (value) {
    'TIEN_MAT' => 'Tiền mặt',
    'VI_DIEN_TU' => provider == 'VNPAY' ? 'VNPAY' : 'Ví điện tử',
    'CHUYEN_KHOAN' => 'Chuyển khoản',
    _ => 'Chưa có phương thức',
  };
  String _status(SettlementView v) =>
      v.isComplete
          ? 'Đã hoàn thành'
          : v.isFinal
          ? 'Đã chốt'
          : 'Chưa chốt';
  Color get _primary => Theme.of(context).colorScheme.primary;

  Widget _row(
    String label,
    num? value, {
    bool strong = false,
    Widget? detail,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingS),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            AppText(
              label,
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.normal,
            ),
            AppText(
              _money(value),
              fontSize: 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ],
        ),
        if (detail != null) detail,
      ],
    ),
  );
  Widget _section(String title, IconData icon, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.spacingM),
    child: ContractSectionCard(title: title, icon: icon, child: child),
  );

  Future<void> _basis(Map<String, dynamic> charge) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder:
            (context) => SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      charge['moTa']?.toString() ?? 'Căn cứ khoản tiền',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    _row('Số tiền', charge['soTien'] as num?),
                    if (charge['donGia'] is num)
                      _row('Đơn giá gốc', charge['donGia'] as num),
                    if (charge['soNgay'] is num)
                      AppText('Số ngày tính: ${charge['soNgay']}'),
                    if (charge['nguonId'] is String)
                      SelectableText(
                        'Chứng từ liên quan: ${charge['nguonId']}',
                      ),
                    if (charge['maChiTietHopDong'] is String)
                      SelectableText('Thiết bị: ${charge['maChiTietHopDong']}'),
                    const SizedBox(height: AppSizes.spacingM),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ),
      );

  Widget _result(SettlementView v) {
    final colors = Theme.of(context).colorScheme;
    final collection = v.collectionRemaining;
    final hasCollection = collection != null && collection > 0;
    final refund = v.refundEntitlement;
    final title =
        !v.isFinal
            ? 'Quyết toán dự kiến'
            : hasCollection
            ? 'Cần thanh toán thêm'
            : refund != null && refund > 0
            ? 'Được hoàn lại'
            : collection == 0 && refund == 0
            ? 'Không phát sinh thu/hoàn'
            : 'Chưa xác định số dư';
    return _section(
      'KẾT QUẢ QUYẾT TOÁN',
      Icons.receipt_long_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hasCollection
                    ? Icons.info_outline
                    : Icons.account_balance_wallet_outlined,
                color: hasCollection ? colors.error : _primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: AppText(title, fontWeight: FontWeight.w600)),
            ],
          ),
          if (hasCollection || (refund != null && refund > 0)) ...[
            const SizedBox(height: 8),
            AppText(
              _money(hasCollection ? collection : refund),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: hasCollection ? colors.error : _primary,
            ),
          ],
          if (refund != null && refund > 0) ...[
            _row('Cửa hàng đã ghi hoàn', v.refundRecorded),
            _row('Còn phải hoàn', v.refundRemaining),
          ],
          if (!v.isFinal)
            const AppText(
              'Chưa phải số tiền cuối. Cửa hàng cần hoàn tất kiểm tra và đối soát.',
              fontSize: 12,
            ),
          if (v.isFinal && !v.isComplete)
            const AppText(
              'Đã chốt quyết toán chưa đồng nghĩa hợp đồng đã hoàn thành.',
              fontSize: 12,
            ),
          for (final reason in v.blockers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppText(reason, color: colors.error, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _returned(SettlementView v) {
    final receipt = v.receipt;
    final devices = apiRows(receipt?['thietBi']);
    final inspected = receipt?['kiemTraLucUtc'] is String;
    return _section(
      '1. Kết quả nhận trả',
      Icons.inventory_2_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            receipt?['thucNhanLuc'] == null
                ? 'Chưa xác nhận nhận đủ thiết bị'
                : 'Backend đã xác nhận nhận đủ thiết bị',
            fontWeight: FontWeight.w600,
          ),
          if (_date(receipt?['thucNhanLuc']) case final String time)
            AppText('Thực nhận: $time', fontSize: 12),
          if (_date(receipt?['ghiNhanLucUtc'], utc: true)
              case final String time)
            AppText('Ghi nhận: $time', fontSize: 12),
          if (_date(receipt?['kiemTraLucUtc'], utc: true)
              case final String time)
            AppText('Kiểm tra: $time', fontSize: 12),
          if (!inspected && receipt?['thucNhanLuc'] != null)
            const AppText('Đang kiểm tra', fontSize: 12),
          for (final device in devices)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (device['anhUrl'] is String)
                    SizedBox(
                      height: 80,
                      child: FutureBuilder<List<int>>(
                        future: _images.putIfAbsent(
                          device['anhUrl'] as String,
                          () => _cubit.returnImage(device['anhUrl'] as String),
                        ),
                        builder:
                            (context, snapshot) =>
                                snapshot.hasData
                                    ? Image.memory(
                                      Uint8List.fromList(snapshot.data!),
                                      fit: BoxFit.contain,
                                    )
                                    : const Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                  AppText(
                    device['tenDongMay']?.toString() ?? 'Thiết bị',
                    fontWeight: FontWeight.w600,
                  ),
                  AppText(
                    'Serial: ${device['soSerial'] ?? 'Chưa có dữ liệu'}',
                    fontSize: 12,
                  ),
                  AppText(
                    device['tinhTrang']?.toString() ??
                        'Chưa ghi nhận tình trạng',
                    fontSize: 12,
                  ),
                  if (device['ketLuan'] == 'DAT')
                    const AppText('Kiểm tra đạt', fontSize: 12),
                  if (device['coHuHong'] == true)
                    const AppText('Có hư hỏng được ghi nhận', fontSize: 12),
                  if (device['thieuPhuKien'] == true)
                    const AppText(
                      'Có phụ kiện thiếu được ghi nhận',
                      fontSize: 12,
                    ),
                  for (final item in apiRows(device['phuKien']))
                    AppText(
                      '${item['ten']}: ${item['tinhTrang'] ?? 'Chưa đối chiếu'}',
                      fontSize: 12,
                    ),
                ],
              ),
            ),
          for (final item in apiRows(receipt?['ngoaiLe']))
            AppText(
              'Ngoại lệ serial ${item['soSerial']}: ${item['lyDo']}',
              fontSize: 12,
            ),
        ],
      ),
    );
  }

  Widget _charges(SettlementView v) => _section(
    '2. Các khoản phải trả',
    Icons.list_alt_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.charges.isEmpty)
          const AppText('Chưa có bảng nghĩa vụ được xác định.'),
        for (final charge in v.charges)
          _row(
            charge['moTa']?.toString() ?? 'Khoản phải trả',
            charge['soTien'] as num?,
            detail: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _basis(charge),
                child: const Text('Xem căn cứ'),
              ),
            ),
          ),
        const Divider(),
        _row('Tổng nghĩa vụ', v.total, strong: true),
      ],
    ),
  );

  Widget _payments(SettlementView v) => _section(
    '3. Tiền đã thanh toán',
    Icons.payments_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Tiền thuê và phí đã thu', v.paidRental, strong: true),
        _row('Tiền cọc ký quỹ đã thu', v.deposit, strong: true),
        const AppText(
          'Tiền cọc là nguồn ký quỹ riêng, chỉ phần phân bổ ở dưới được dùng bù nghĩa vụ.',
          fontSize: 12,
        ),
        for (final source in v.sources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            isThreeLine: true,
            title: AppText(_money(source['soTien'] as num?), fontSize: 13),
            subtitle: AppText(
              '${_method(source['phuongThuc'], source['nhaCungCap'])} • ${source['trangThai'] ?? 'Chưa có trạng thái'}\n${_date(source['thoiGian']) ?? 'Chưa ghi nhận thời gian'}',
              fontSize: 12,
            ),
            onTap:
                () => _basis({
                  'moTa': 'Giao dịch ${source['maThanhToan']}',
                  'soTien': source['soTien'],
                  'nguonId': source['maThamChieu'],
                }),
          ),
      ],
    ),
  );

  Widget _deposit(SettlementView v) {
    final sourceIds =
        v.sources
            .where((s) => s['loaiThanhToan'] == 'TIEN_COC')
            .map((s) => s['maThanhToan'])
            .toSet();
    final rows = v.allocations.where(
      (a) => sourceIds.contains(a['maThanhToanNguon']),
    );
    return _section(
      '4. Khấu trừ cọc',
      Icons.shield_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            _row(
              v.charges
                      .where((c) => c['id'] == row['maKhoan'])
                      .map((c) => c['moTa'].toString())
                      .firstOrNull ??
                  'Nghĩa vụ đã phân bổ',
              row['soTien'] as num?,
            ),
          _row('Tổng khấu trừ', v.depositUsed, strong: true),
          if (v.deposit != null && v.deposit! > 0 && v.depositUsed != null)
            AppText(
              'Tỷ lệ khấu trừ: ${(100 * v.depositUsed! / v.deposit!).clamp(0, 100).toStringAsFixed(0)}%',
              fontSize: 12,
            ),
        ],
      ),
    );
  }

  Widget _tracking(SettlementView v) {
    final steps = <ContractTimelineStep>[];
    for (final payment in v.payments) {
      final refund = (payment['loaiThanhToan'] as String? ?? '').startsWith(
        'HOAN_',
      );
      final recorded = payment['trangThai'] == 'DA_HOAN';
      final acknowledged = payment['khachNhanHoanLucUtc'] != null;
      steps.add(
        ContractTimelineStep(
          title:
              acknowledged
                  ? 'Khách đã xác nhận nhận tiền'
                  : recorded
                  ? payment['phuongThuc'] == 'TIEN_MAT'
                      ? 'Cửa hàng đã ghi nhận hoàn tiền mặt'
                      : 'Cửa hàng đã ghi nhận hoàn tiền'
                  : refund
                  ? 'Khoản hoàn đang chờ xử lý'
                  : 'Khoản thu ${payment['trangThai'] ?? 'chưa rõ'}',
          subtitle:
              '${_money(payment['soTien'] as num?)} • ${_method(payment['phuongThuc'])}${payment['maThamChieu'] == null ? '' : '\n${payment['maThamChieu']}'}',
          timestamp: _date(
            payment['khachNhanHoanLucUtc'] ?? payment['thoiGian'],
            utc: payment['khachNhanHoanLucUtc'] != null,
          ),
          state:
              acknowledged || recorded || payment['trangThai'] == 'THANH_CONG'
                  ? TimelineStepState.completed
                  : TimelineStepState.active,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingM),
      child:
          steps.isEmpty
              ? _section(
                '5. Theo dõi thu / hoàn',
                Icons.timeline,
                const AppText(
                  'Chưa phát sinh giao dịch thu/hoàn theo quyết toán.',
                ),
              )
              : ContractProgressTimeline(
                title: '5. THEO DÕI THU / HOÀN',
                steps: steps,
              ),
    );
  }

  Future<void> _feedback(
    SettlementView v,
    String type, {
    String? paymentId,
  }) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text(
              type == 'CHUA_NHAN_HOAN'
                  ? 'Chưa nhận tiền hoàn'
                  : 'Có thắc mắc về quyết toán',
            ),
            content: TextField(
              controller: controller,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Nội dung phản hồi'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.of(dialog).pop(controller.text.trim());
                  }
                },
                child: const Text('Gửi phản hồi'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (text != null && mounted) {
      await _cubit.settlementFeedback(
        type,
        reason: text,
        paymentId: paymentId,
        expectedHash: v.hash,
      );
    }
  }

  Future<void> _acknowledge(SettlementView v) async {
    final rows =
        v.payments
            .where((p) => v.receivableRefundIds.contains(p['maThanhToan']))
            .toList();
    Map<String, dynamic>? chosen;
    if (rows.length == 1) {
      chosen = rows.single;
    } else {
      chosen = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder:
            (sheet) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in rows)
                    ListTile(
                      title: Text(
                        '${_money(p['soTien'] as num?)} • ${_method(p['phuongThuc'])}',
                      ),
                      subtitle: Text(p['maThanhToan'].toString()),
                      onTap: () => Navigator.of(sheet).pop(p),
                    ),
                ],
              ),
            ),
      );
    }
    if (chosen == null || !mounted) return;
    final payment = chosen;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final theme = Theme.of(dialog);
        final colors = theme.colorScheme;
        return Dialog(
          backgroundColor: colors.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingL,
            vertical: AppSizes.spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius * 2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.spacingM),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.pageMargin),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingS),
                  AppText(
                    'Xác nhận nhận tiền',
                    style: theme.textTheme.titleMedium,
                    fontWeight: FontWeight.w600,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.spacingS),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AppText(
                      const AppMoneyFormatter().format(
                        payment['soTien'] as num?,
                      ),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSizes.pageMargin),
                  Container(
                    padding: const EdgeInsets.all(AppSizes.pageMargin),
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadius,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'Hợp đồng',
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        AppText(
                          v.contractId,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        const SizedBox(height: AppSizes.spacingS / 2),
                        AppText(
                          _method(payment['phuongThuc'], payment['nhaCungCap']),
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.pageMargin),
                  AppText(
                    'Chỉ xác nhận khi bạn đã nhận đủ tiền hoàn.',
                    color: colors.onSurfaceVariant,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.spacingM),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final later = OutlinedButton(
                        onPressed: () => Navigator.of(dialog).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            AppSizes.buttonHeight,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.spacingM,
                            vertical: AppSizes.spacingS,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.borderRadius,
                            ),
                          ),
                        ),
                        child: const AppText('Để sau'),
                      );
                      final confirm = PrimaryButton(
                        text: 'Đã nhận tiền',
                        onPressed: () => Navigator.of(dialog).pop(true),
                      );
                      if (constraints.maxWidth < 260 ||
                          MediaQuery.textScalerOf(context).scale(14) > 18) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            later,
                            const SizedBox(height: AppSizes.spacingS),
                            confirm,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: later),
                          const SizedBox(width: AppSizes.spacingS),
                          Expanded(child: confirm),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (accepted == true && mounted) {
      await _cubit.settlementFeedback(
        'DA_NHAN_HOAN',
        paymentId: payment['maThanhToan'] as String,
        expectedHash: v.hash,
        expectedAmount: payment['soTien'] as num?,
      );
    }
  }

  Future<void> _confirmDecision(
    SettlementView v,
    String type, {
    Map<String, dynamic>? feedback,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text(
              type == 'DONG_Y_QUYET_TOAN'
                  ? 'Đồng ý quyết toán'
                  : type == 'RUT_PHAN_HOI'
                  ? 'Rút phản hồi'
                  : 'Chấp nhận kết quả xử lý',
            ),
            content: Text(
              '${v.contractId}\n${type == 'DONG_Y_QUYET_TOAN' ? 'Bạn xác nhận đồng ý các khoản trong bản quyết toán đã xem. Hợp đồng chỉ hoàn tất khi đủ mọi điều kiện.' : feedback?['traLoi']?.toString() ?? 'Bạn xác nhận không tiếp tục phản hồi này.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Quay lại'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
    );
    if (accepted == true && mounted) {
      await _cubit.settlementFeedback(
        type,
        expectedHash: v.hash,
        feedbackId: feedback?['id'] as String?,
        replySeenAt: feedback?['traLoiLucUtc'] as String?,
      );
    }
  }

  Future<void> _review(SettlementView v) async {
    try {
      final data = await _cubit.settlementReviewData();
      if (data == null || !mounted) return;
      final devices =
          data.contract.assignedDevices
              .where((d) => v.reviewEligibleIds.contains(d.detailId))
              .toList();
      if (devices.isEmpty) {
        await _cubit.load();
        return;
      }
      final detailId =
          devices.length == 1
              ? devices.single.detailId
              : await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder:
                    (sheet) => ReviewDevicePicker(
                      devices: devices,
                      models: data.contract.bookedDevices,
                      onSelected: (id) => Navigator.of(sheet).pop(id),
                    ),
              );
      if (detailId != null && mounted) {
        await context.push('/review/${Uri.encodeComponent(detailId)}');
        await _cubit.load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa tải được điều kiện đánh giá. Hãy làm mới quyết toán.',
            ),
          ),
        );
      }
    }
  }

  Widget? _actions(ContractDetailState state) {
    final v = state.settlement;
    if (v == null ||
        state.error != null ||
        state.uncertain ||
        v.stale ||
        !v.isFinal ||
        v.isComplete) {
      return null;
    }
    final enabled = !state.loading && !state.submitting;
    if (v.receivableRefundIds.isNotEmpty) {
      return PrimaryButton(
        text:
            v.receivableRefundIds.length == 1
                ? 'Tôi đã nhận ${_money(v.payments.firstWhere((p) => p['maThanhToan'] == v.receivableRefundIds.single)['soTien'] as num?)}'
                : 'Xác nhận khoản hoàn đã nhận',
        isLoading: state.submitting,
        onPressed: enabled ? () => _acknowledge(v) : null,
      );
    }
    if (v.allows('thanhToan') &&
        v.gatewayReady &&
        (v.collectionRemaining ?? 0) > 0) {
      return PrimaryButton(
        text: 'Thanh toán ${_money(v.collectionRemaining)}',
        isLoading: state.submitting,
        onPressed:
            !enabled
                ? null
                : () async {
                  final url = await _cubit.settlementPayment();
                  if (url == null || !mounted) return;
                  final uri = Uri.tryParse(url);
                  if (uri != null && uri.scheme == 'https') {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
      );
    }
    if (v.allows('dongYQuyetToan')) {
      return PrimaryButton(
        text: 'Đồng ý quyết toán',
        isLoading: state.submitting,
        onPressed:
            enabled ? () => _confirmDecision(v, 'DONG_Y_QUYET_TOAN') : null,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<ContractDetailCubit, ContractDetailState>(
      builder: (context, state) {
        final v = state.settlement;
        final action = _actions(state);
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chi tiết quyết toán',
                  style: TextStyle(fontSize: 17),
                ),
                AppText(widget.contractId, fontSize: 11),
              ],
            ),
            actions: [
              if (v != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: AppText(_status(v), fontSize: 11, color: _primary),
                  ),
                ),
            ],
          ),
          bottomNavigationBar:
              action == null
                  ? null
                  : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.pageMargin),
                      child: action,
                    ),
                  ),
          body:
              v == null && state.loading
                  ? const SnapLoadingView(message: 'Đang tải quyết toán')
                  : RefreshIndicator(
                    onRefresh: () => _cubit.load(force: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSizes.pageMargin),
                      children: [
                        if (state.loading)
                          const Center(child: SnapButtonLoader()),
                        if (state.error != null || state.uncertain)
                          _section(
                            'Thông tin chưa cập nhật',
                            Icons.error_outline,
                            Column(
                              children: [
                                AppText(
                                  state.error ??
                                      'Chưa rõ kết quả. Hãy đối soát trước khi thao tác tiếp.',
                                ),
                                TextButton(
                                  onPressed: () => _cubit.load(force: true),
                                  child: const Text('Tải lại để đối soát'),
                                ),
                              ],
                            ),
                          ),
                        if (v != null) ...[
                          _result(v),
                          _returned(v),
                          _charges(v),
                          _payments(v),
                          _deposit(v),
                          _tracking(v),
                          if ((v.collectionRemaining ?? 0) > 0 &&
                              !v.gatewayReady)
                            _section(
                              'Thanh toán chưa sẵn sàng',
                              Icons.info_outline,
                              const AppText(
                                'VNPAY Sandbox chưa sẵn sàng. Không tự chuyển phương thức hoặc coi đã thanh toán.',
                              ),
                            ),
                          if (v.allows('phanHoi'))
                            _section(
                              'Có thắc mắc về quyết toán?',
                              Icons.help_outline,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextButton(
                                    onPressed:
                                        state.submitting ||
                                                state.loading ||
                                                state.uncertain
                                            ? null
                                            : () =>
                                                _feedback(v, 'KHONG_DONG_Y'),
                                    child: const Text('Gửi phản hồi'),
                                  ),
                                  for (final p in v.payments.where(
                                    (p) =>
                                        p['trangThai'] == 'DA_HOAN' &&
                                        p['khachNhanHoanLucUtc'] == null,
                                  ))
                                    TextButton(
                                      onPressed:
                                          state.submitting ||
                                                  state.loading ||
                                                  state.uncertain
                                              ? null
                                              : () => _feedback(
                                                v,
                                                'CHUA_NHAN_HOAN',
                                                paymentId:
                                                    p['maThanhToan'] as String,
                                              ),
                                      child: Text(
                                        'Chưa nhận ${_money(p['soTien'] as num?)}',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          for (final feedback in v.feedback)
                            _section(
                              'Phản hồi ${feedback['trangThai'] ?? ''}',
                              Icons.chat_bubble_outline,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppText(
                                    feedback['noiDung']?.toString() ?? '',
                                  ),
                                  if (feedback['traLoi'] is String)
                                    AppText(feedback['traLoi'] as String),
                                  if (feedback['duocChapNhan'] == true)
                                    TextButton(
                                      onPressed:
                                          state.submitting ||
                                                  state.loading ||
                                                  state.uncertain
                                              ? null
                                              : () => _confirmDecision(
                                                v,
                                                'CHAP_NHAN_KET_QUA',
                                                feedback: feedback,
                                              ),
                                      child: const Text(
                                        'Chấp nhận kết quả xử lý',
                                      ),
                                    ),
                                  if (feedback['duocRut'] == true)
                                    TextButton(
                                      onPressed:
                                          state.submitting ||
                                                  state.loading ||
                                                  state.uncertain
                                              ? null
                                              : () => _confirmDecision(
                                                v,
                                                'RUT_PHAN_HOI',
                                                feedback: feedback,
                                              ),
                                      child: const Text('Rút phản hồi'),
                                    ),
                                ],
                              ),
                            ),
                          if (v.isComplete && v.reviewEligibleIds.isNotEmpty)
                            TextButton(
                              onPressed: () => _review(v),
                              child: const Text('Đánh giá thiết bị'),
                            ),
                        ],
                        const SizedBox(height: AppSizes.spacingM),
                      ],
                    ),
                  ),
        );
      },
    ),
  );
}
