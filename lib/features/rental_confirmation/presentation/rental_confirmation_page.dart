import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../rental/bloc/rental_bloc.dart';
import 'bottom_sheets/change_branch_bottom_sheet.dart';
import '../../../../core/widgets/app_availability_calendar.dart';
import '../../identity_verification/presentation/widgets/verification_progress.dart';
import '../../../../core/widgets/reservation_timer.dart';
import '../../../../domain/entities/customer_profile.dart';


class RentalConfirmationPage extends StatefulWidget {
  const RentalConfirmationPage({super.key});

  @override
  State<RentalConfirmationPage> createState() => _RentalConfirmationPageState();
}

class _RentalConfirmationPageState extends State<RentalConfirmationPage> {
  @override
  void initState() {
    super.initState();
    final bloc = context.read<RentalBloc>();
    if (bloc.state.customerProfile == null) {
      bloc.add(const LoadCustomerProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const RentalConfirmationView();
  }
}

class RentalConfirmationView extends StatelessWidget {
  const RentalConfirmationView({super.key});

  void _showCustomerProfileDialog(BuildContext context, CustomerProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const AppText('Thông tin người thuê', fontSize: 18, fontWeight: FontWeight.bold),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildProfileDetailRow(context, 'Họ và tên:', profile.hoTen),
                _buildProfileDetailRow(context, 'Số điện thoại:', _maskPhone(profile.soDienThoai)),
                _buildProfileDetailRow(context, 'Email:', profile.email ?? 'Chưa có thông tin'),
                const Divider(height: 24),
                _buildProfileDetailRow(context, 'Số CCCD:', profile.cccd != null ? _maskString(profile.cccd) : 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Ngày sinh:', profile.ngaySinh ?? 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Giới tính:', profile.gioiTinh ?? 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Quốc tịch:', profile.quocTich ?? 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Thường trú:', profile.diaChiThuongTru ?? 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Ngày cấp:', profile.ngayCap ?? 'Chưa có thông tin'),
                _buildProfileDetailRow(context, 'Nơi cấp:', profile.noiCap ?? 'Chưa có thông tin'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const AppText('Đóng', color: Colors.blue),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AppText(
              label,
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: AppText(
              value,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePeriodBottomSheet(
    BuildContext context,
    RentalState state,
  ) async {
    if (state.selectedDevice == null) return;
    
    final result = await AppAvailabilityCalendar.show(
      context,
      currentPickup: state.pickupDate,
      currentReturn: state.returnDate,
      branchId: state.branchId,
      deviceId: state.selectedDevice!.id,
      quantity: state.quantity,
      reservationId: state.maGiuCho,
    );

    if (result != null && context.mounted) {
      final newPickup = result['pickup']!;
      final newReturn = result['return']!;
      final oldPickup = state.pickupDate;
      final oldReturn = state.returnDate;

      if (oldPickup == null || oldReturn == null || 
          !newPickup.isAtSameMomentAs(oldPickup) || 
          !newReturn.isAtSameMomentAs(oldReturn)) {
        context.read<RentalBloc>().add(
          UpdateRentalPeriod(
            pickupDate: newPickup,
            returnDate: newReturn,
          ),
        );
      }
    }
  }

  void _showChangeBranchBottomSheet(
    BuildContext context,
    RentalState state,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ChangeBranchBottomSheet(
            currentBranchId: state.branchId ?? (state.selectedDevice!.branches.isNotEmpty ? state.selectedDevice!.branches.first.branchId : ''),
            branches: state.selectedDevice!.branches,
          ),
    );

    if (result != null && context.mounted) {
      context.read<RentalBloc>().add(UpdateRentalBranch(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldCancel = await showCancelReservationDialog(context);
        if (shouldCancel && context.mounted) {
          context.read<RentalBloc>().add(const CancelReservation());
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/device/${context.read<RentalBloc>().state.selectedDevice?.id}');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () async {
              final shouldCancel = await showCancelReservationDialog(context);
              if (shouldCancel && context.mounted) {
                context.read<RentalBloc>().add(const CancelReservation());
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/device/${context.read<RentalBloc>().state.selectedDevice?.id}');
                }
              }
            },
          ),
          title: AppText(
            'Xác nhận thuê',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Builder(
                  builder: (context) {
                    final initialTimeRemaining = context.select((RentalBloc bloc) => bloc.state.initialTimeRemaining);
                    final isSyncing = context.select((RentalBloc bloc) => bloc.state.isSyncingReservation);
                    final stopwatch = context.read<RentalBloc>().reservationStopwatch;
                    
                    if (initialTimeRemaining != null) {
                      return ReservationTimer(
                        initialTimeRemaining: initialTimeRemaining,
                        stopwatch: stopwatch,
                        isSyncing: isSyncing,
                        onExpired: () {
                          context.read<RentalBloc>().add(const CheckReservationStatus());
                        },
                        onResume: () {
                          context.read<RentalBloc>().add(const FetchActiveReservation());
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<RentalBloc, RentalState>(
              listenWhen: (previous, current) => previous.isReservationExpired != current.isReservationExpired,
              listener: (context, state) {
                if (state.isReservationExpired) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thời gian giữ chỗ đã hết hạn. Vui lòng thực hiện lại.')),
                  );
                  if (context.canPop()) {
                    context.pop();
                  } else if (state.selectedDevice != null) {
                    context.go('/device/${state.selectedDevice!.id}');
                  } else {
                    context.go('/');
                  }
                }
              },
            ),
            BlocListener<RentalBloc, RentalState>(
              listenWhen: (previous, current) => !previous.showInsufficientDeviceDialog && current.showInsufficientDeviceDialog,
              listener: (context, state) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      title: const AppText('Chi nhánh không đủ thiết bị', fontSize: 18, fontWeight: FontWeight.bold),
                      content: const AppText(
                        'Chi nhánh này không đủ số lượng thiết bị cho thời gian thuê bạn đã chọn. Vui lòng chọn chi nhánh khác hoặc đổi thời gian thuê.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: AppText(
                            'Đã hiểu',
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            BlocListener<RentalBloc, RentalState>(
              listenWhen: (previous, current) => !previous.showBranchNotFoundDialog && current.showBranchNotFoundDialog,
              listener: (context, state) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      title: const AppText('Cửa hàng không tồn tại', fontSize: 18, fontWeight: FontWeight.bold),
                      content: const AppText(
                        'Cửa hàng mới không tồn tại hoặc đang khóa. Vui lòng chọn chi nhánh khác.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: AppText(
                            'Đã hiểu',
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            BlocListener<RentalBloc, RentalState>(
              listenWhen: (previous, current) => previous.isCreatingContract != current.isCreatingContract || previous.createContractError != current.createContractError || previous.contractId != current.contractId,
              listener: (context, state) {
                if (state.createContractError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.createContractError!)),
                  );
                } else if (!state.isCreatingContract && state.contractId != null) {
                  // Navigate to Contract details with the actual ID
                  context.pushReplacement('/contract/${state.contractId}');
                }
              },
            ),
          ],
          child: BlocBuilder<RentalBloc, RentalState>(
            builder: (context, state) {
              return Column(
                children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Using VerificationProgress but setting it to step 3/4
                      // The current VerificationProgress takes totalSteps
                      const VerificationProgress(currentStep: 3, totalSteps: 4),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AppText(
                                    'Kiểm tra thông tin thuê',
                                    fontWeight: FontWeight.bold,
                                  ),
                                  SizedBox(height: 4),
                                  AppText(
                                    'Vui lòng kiểm tra lại các thông tin bên dưới trước khi chuyển sang bước ký kết hợp đồng điện tử.',
                                    fontSize: 12,
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
                      ),
                      if (AppConfig.enableDemoMode && state.priceQuote == null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppText(
                                  'Chế độ demo — dữ liệu mẫu chưa xác nhận lịch trống và báo giá.',
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Device
                      _buildSectionHeader(
                        context,
                        'Thiết bị thuê',
                        actionText: 'Xem chi tiết',
                        onAction: () {
                          // View device detail in review mode. We pass mock ID.
                          context.push('/device/sony_a7iv?reviewMode=true');
                        },
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/camera.png',
                                  width: 40,
                                  errorBuilder:
                                      (c, e, s) => Icon(
                                        Icons.camera_alt,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    state.selectedDevice?.name ?? 'Thiết bị',
                                    fontWeight: FontWeight.bold,
                                  ),
                                  SizedBox(height: 2),
                                  AppText(
                                    state.selectedDevice?.category ?? '',
                                    fontSize: 12,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: 4),
                                  AppText(
                                    'Số lượng: ${state.quantity}',
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
                              state.isChecking ? 'Đang tính...' : state.checkError != null ? 'Lỗi' : '${currencyFormatter.format(state.dailyPrice)} / ngày',
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Rental Period
                      _buildSectionHeader(
                        context,
                        'Thời gian thuê',
                        actionText: 'Thay đổi',
                        onAction:
                            () => _showChangePeriodBottomSheet(context, state),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppText(
                                      'Ngày nhận:',
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                    const SizedBox(height: 4),
                                    AppText(
                                      DateFormat('dd/MM/yyyy').format(
                                        state.pickupDate ?? DateTime.now(),
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    AppText(
                                      '${_getWeekday(state.pickupDate ?? DateTime.now())} • ${DateFormat('HH:mm').format(state.pickupDate ?? DateTime.now())}',
                                      fontSize: 12,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    AppText(
                                      'Ngày trả:',
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                    const SizedBox(height: 4),
                                    AppText(
                                      DateFormat('dd/MM/yyyy').format(
                                        state.returnDate ?? DateTime.now(),
                                      ),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    AppText(
                                      '${_getWeekday(state.returnDate ?? DateTime.now())} • ${DateFormat('HH:mm').format(state.returnDate ?? DateTime.now())}',
                                      fontSize: 12,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Tổng thời gian:',
                                ),
                                AppText(
                                  state.isChecking ? 'Đang tính...' : state.checkError != null ? 'Lỗi' : '${state.rentalDays} ngày',
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Branch
                      _buildSectionHeader(
                        context,
                        'Địa điểm nhận thiết bị',
                        actionText: 'Thay đổi',
                        onAction:
                            () => _showChangeBranchBottomSheet(context, state),
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    _getBranchName(
                                      state.branchId ?? 'branch_1',
                                      state,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  const SizedBox(height: 4),
                                  AppText(
                                    _getBranchAddress(
                                      state.branchId ?? 'branch_1',
                                      state,
                                    ),
                                    fontSize: 13,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                      SizedBox(width: 4),
                                      AppText(
                                        '08:00 - 21:00',
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const AppText(
                                          'Còn thiết bị',
                                          fontSize: 10,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Renter Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AppText(
                            'Thông tin người thuê',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const AppText(
                              'Đã xác minh CCCD',
                              color: Colors.green,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.isLoadingProfile)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else if (state.profileError != null)
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    AppText(
                                      'Không thể tải hồ sơ: ${state.profileError}',
                                      color: Colors.red,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        context.read<RentalBloc>().add(const LoadCustomerProfile());
                                      },
                                      child: const Text('Thử lại'),
                                    )
                                  ],
                                ),
                              )
                            else if (state.customerProfile != null) ...[
                              _buildInfoRow(
                                context,
                                'Họ và tên:',
                                state.customerProfile!.hoTen,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                context, 
                                'Số CCCD:', 
                                _maskString(state.customerProfile!.cccd),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                context,
                                'Số điện thoại:',
                                _maskPhone(state.customerProfile!.soDienThoai),
                              ),
                              const Divider(height: 24),
                              Center(
                                child: InkWell(
                                  onTap: () {
                                    _showCustomerProfileDialog(context, state.customerProfile!);
                                  },
                                  child: AppText(
                                    'Xem thông tin',
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Cost
                      const AppText(
                        'Chi phí thuê',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 12),
                      
                      state.isChecking
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 12),
                                    AppText('Đang cập nhật báo giá...', color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            )
                          : state.checkError != null
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      AppText(
                                        state.checkError!,
                                        color: Colors.red,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton(
                                        onPressed: () => context.read<RentalBloc>().add(const FetchAvailabilityAndQuote()),
                                        child: const Text('Thử lại'),
                                      ),
                                    ],
                                  ),
                                )
                              : state.priceQuote == null && !AppConfig.enableDemoMode
                                  ? const SizedBox.shrink()
                                  : Container(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Giá thuê:\n${currencyFormatter.format(state.dailyPrice)} x ${state.rentalDays} ngày',
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                AppText(
                                  currencyFormatter.format(state.subtotal),
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Ưu đãi thành viên mới (-${state.discountPercent}%):',
                                  color: Colors.green,
                                  fontSize: 13,
                                ),
                                AppText(
                                  '-${currencyFormatter.format(state.discountAmount)}',
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const AppText(
                                  'Tiền thuê sau giảm:',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                AppText(
                                  currencyFormatter.format(
                                    state.rentalAfterDiscount,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Giá trị thiết bị (tham chiếu):',
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                AppText(
                                  state.selectedDevice?.deviceValue ?? 'Chưa xác định',
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Tỷ lệ đặt cọc yêu cầu:',
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                const AppText(
                                  '20%',
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const AppText(
                                  'Tiền cọc dự kiến (hoàn lại):',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                AppText(
                                  currencyFormatter.format(state.deposit),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Tiền thuê thiết bị:',
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                AppText(
                                  currencyFormatter.format(
                                    state.rentalAfterDiscount,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Tiền cọc hoàn trả:',
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                                AppText(
                                  currencyFormatter.format(state.deposit),
                                  fontWeight: FontWeight.w500,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppText(
                                  'Tổng dự kiến thanh toán:',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                AppText(
                                  currencyFormatter.format(state.totalPayment),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      AppText(
                        '* Tiền cọc được xử lý theo điều khoản của hợp đồng thuê và sẽ được hoàn trả theo chính sách của SNAPLEASE ngay sau khi kiểm tra thiết bị hoàn tất.',
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 24),

                      // Notes
                      const AppText(
                        'Lưu ý trước khi tiếp tục',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                              context,
                              'Thiết bị thực tế và tình trạng ngoại quan sẽ được đồng kiểm xác nhận trước khi bàn giao.',
                            ),
                            _buildTipBullet(
                              context,
                              'Khách hàng cần mang CCCD bản gốc để đối chiếu khi nhận thiết bị tại cửa hàng.',
                            ),
                            _buildTipBullet(
                              context,
                              'Giá trị cuối cùng và chính sách phát sinh được quy định chi tiết trong hợp đồng thuê.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: state.isConfirmed,
                              onChanged: (value) {
                                if (value != null) {
                                  context.read<RentalBloc>().add(
                                    ToggleConfirmation(value),
                                  );
                                }
                              },
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          const Expanded(
                            child: AppText(
                              'Tôi đã kiểm tra và xác nhận các thông tin thuê ở trên là chính xác và sẵn sàng ký hợp đồng.',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              // Warning for changed criteria
              if (!state.isChecking && !state.isCriteriaMatchingReservation && state.maGiuCho != null)
                Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(
                          'Thông tin thuê đã thay đổi, không khớp với lượt giữ chỗ hiện tại.',
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
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
                            'Tạm tính (kèm cọc)',
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          AppText(
                            state.isChecking ? 'Đang tính...' : state.checkError != null ? 'Lỗi' : currencyFormatter.format(state.totalPayment),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: PrimaryButton(
                        text: state.isCreatingContract ? 'Đang tạo...' : 'Tiếp tục lập hợp đồng →',
                        onPressed:
                            state.isConfirmed && state.isValidToRent && state.isCriteriaMatchingReservation && !state.isCreatingContract
                                ? () {
                                    context.read<RentalBloc>().add(const CreateContract());
                                  }
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    )));
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    required String actionText,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(title, fontWeight: FontWeight.bold, fontSize: 16),
        InkWell(
          onTap: onAction,
          child: AppText(
            actionText,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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

  Widget _buildTipBullet(BuildContext context, String text) {
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

  String _getWeekday(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Thứ hai';
      case 2:
        return 'Thứ ba';
      case 3:
        return 'Thứ tư';
      case 4:
        return 'Thứ năm';
      case 5:
        return 'Thứ sáu';
      case 6:
        return 'Thứ bảy';
      case 7:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  String _maskString(String? val) {
    if (val == null || val.length < 4) return '***';
    return '${val.substring(0, 3)}*****${val.substring(val.length - 3)}';
  }

  String _maskPhone(String? val) {
    if (val == null || val.length < 4) return '***';
    return '${val.substring(0, 4)} *** ${val.substring(val.length - 3)}';
  }

  String _getBranchName(String branchId, RentalState state) {
    if (state.selectedDevice != null) {
      try {
        final branch = state.selectedDevice!.branches.firstWhere((b) => b.branchId == branchId);
        return branch.branchName;
      } catch (e) {
        // Not found
      }
    }
    if (branchId == 'branch_1') return 'Chi nhánh Quận 1';
    if (branchId == 'branch_2') return 'Chi nhánh Quận 7';
    return 'Chi nhánh không xác định';
  }

  String _getBranchAddress(String branchId, RentalState state) {
    if (state.selectedDevice != null) {
      try {
        final branch = state.selectedDevice!.branches.firstWhere((b) => b.branchId == branchId);
        return branch.address;
      } catch (e) {
        // Not found
      }
    }
    if (branchId == 'branch_1') {
      return '123 Nguyễn Huệ,\nPhường Bến Nghé,\nQuận 1, TP. Hồ Chí Minh';
    }
    if (branchId == 'branch_2') {
      return '104 Nguyễn Thị Thập,\nTân Phú,\nQuận 7, TP. Hồ Chí Minh';
    }
    return '';
  }
}
