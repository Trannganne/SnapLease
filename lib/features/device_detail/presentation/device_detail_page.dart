import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/device_detail_repository.dart';
import '../bloc/device_detail_bloc.dart';
import '../bloc/device_detail_event.dart';
import '../bloc/device_detail_state.dart';
import '../../rental/bloc/rental_bloc.dart';
import '../../../app/router/app_router.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_event.dart';
import '../../cart/bloc/cart_state.dart';
import 'widgets/device_detail_widgets.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';

class DeviceDetailPage extends StatelessWidget {
  final String deviceId;
  final bool reviewMode;

  const DeviceDetailPage({
    super.key,
    required this.deviceId,
    this.reviewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              DeviceDetailBloc(repository: DeviceDetailRepository())
                ..add(LoadDeviceDetail(deviceId)),
      child: DeviceDetailView(reviewMode: reviewMode),
    );
  }
}

class DeviceDetailView extends StatelessWidget {
  final bool reviewMode;

  const DeviceDetailView({super.key, this.reviewMode = false});

  @override
  Widget build(BuildContext context) {
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: AppText(
          'Chi Tiết Thiết Bị',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                BlocBuilder<CartBloc, CartState>(
                  builder: (context, cartState) {
                    final count = cartState.totalLinesCount;
                    return GestureDetector(
                      onTap: () {
                        context.push(AppRouter.cart);
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            size: 24,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          if (count > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: AppText(
                                  '$count',
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                UserAvatar(
                  displayName: 'Tuan',
                  radius: 16,
                  onTap: () {
                    // TODO: route to profile
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocConsumer<DeviceDetailBloc, DeviceDetailState>(
        listener: (context, state) {
          if (state.status == DeviceDetailStatus.loaded &&
              state.detail != null) {
            context.read<RentalBloc>().add(InitializeRental(state.detail!));
            context.read<RentalBloc>().add(const FetchActiveReservation());
          }
        },
        builder: (context, state) {
          if ((state.status == DeviceDetailStatus.initial ||
                  state.status == DeviceDetailStatus.loading) &&
              state.detail == null) {
            return const SnapLoadingView(
              message: 'Đang tải chi tiết thiết bị',
              size: RetroCameraLoader.large,
            );
          }

          if (state.status == DeviceDetailStatus.error ||
              state.detail == null) {
            return const Center(child: Text('Đã có lỗi xảy ra'));
          }

          final detail = state.detail!;

          return BlocConsumer<RentalBloc, RentalState>(
            listenWhen:
                (previous, current) =>
                    previous.isCreatingReservation !=
                        current.isCreatingReservation ||
                    (previous.maGiuCho == null && current.maGiuCho != null) ||
                    (previous.contractId == null && current.contractId != null),
            listener: (context, rentalState) {
              if (rentalState.contractId != null) {
                context.push('/contract/${rentalState.contractId}');
                return;
              }
              if (!rentalState.isCreatingReservation) {
                if (rentalState.reservationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(rentalState.reservationError!),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                } else if (rentalState.maGiuCho != null) {
                  if (rentalState.daXacNhanThongTin) {
                    context.push('/rental-confirmation');
                  } else {
                    context.push('/identity-verification');
                  }
                }
              }
            },
            builder: (context, rentalState) {
              if (rentalState.selectedDevice == null) {
                return const SnapLoadingView(
                  message: 'Đang chuẩn bị thông tin thuê',
                  size: RetroCameraLoader.large,
                );
              }

              return SnapLoadingOverlay(
                loading: rentalState.isCreatingReservation,
                message: 'Đang tạo yêu cầu giữ chỗ',
                avoidKeyboardInsets: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSizes.pageMargin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DeviceImageGallery(
                              images: detail.images,
                              badges: detail.badges,
                            ),
                            const SizedBox(height: 24),
                            BasicInfoSection(detail: detail),
                            const SizedBox(height: 24),
                            StatusCard(
                              availableQuantity: detail.availableQuantity,
                            ),
                            const SizedBox(height: 24),
                            RentalPeriodCard(detail: detail),
                            const SizedBox(height: 24),
                            RentalInfoCard(detail: detail),
                            const SizedBox(height: 24),
                            DescriptionSection(description: detail.description),
                            const SizedBox(height: 24),
                            BranchAvailabilitySection(
                              branches: detail.branches,
                              selectedBranchId: rentalState.branchId,
                              onChanged:
                                  reviewMode
                                      ? null
                                      : (id) => context.read<RentalBloc>().add(
                                        UpdateRentalBranch(id),
                                      ),
                            ),
                            const SizedBox(height: 24),
                            ReviewSection(
                              reviews: detail.reviews,
                              rating: detail.rating,
                              reviewCount: detail.reviewCount,
                            ),
                            const SizedBox(height: 24),
                            PriceSummaryCard(detail: detail),
                            const SizedBox(
                              height: 48,
                            ), // Padding bottom before action bar
                          ],
                        ),
                      ),
                    ),
                    if (!reviewMode)
                      DeviceDetailBottomBar(
                        onAddToCart:
                            rentalState.isValidToRent
                                ? () {
                                  context.read<CartBloc>().add(
                                    CartItemAdded(
                                      detail.id,
                                      rentalState.branchId!,
                                      rentalState.quantity,
                                      rentalState.pickupDate!,
                                      rentalState.returnDate!,
                                    ),
                                  );
                                }
                                : null,
                        pricePerDay: detail.pricePerDay,
                        rentalState: rentalState,
                        onContinue:
                            (rentalState.isValidToRent ||
                                    (AppConfig.enableDemoMode &&
                                        rentalState.isValidForDemo))
                                ? () {
                                  if (rentalState.isCreatingReservation) return;
                                  if (AppConfig.enableDemoMode) {
                                    context.push('/identity-verification');
                                  } else {
                                    if (rentalState.maGiuCho != null) {
                                      if (rentalState.daXacNhanThongTin) {
                                        context.push('/rental-confirmation');
                                      } else {
                                        context.push('/identity-verification');
                                      }
                                    } else {
                                      context.read<RentalBloc>().add(
                                        const CreateReservation(),
                                      );
                                    }
                                  }
                                }
                                : null,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
