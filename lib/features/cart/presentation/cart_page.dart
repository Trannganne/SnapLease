import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../rental/bloc/rental_bloc.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import 'widgets/cart_branch_header.dart';
import 'widgets/cart_empty_view.dart';
import 'widgets/cart_item_card.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';
import 'widgets/cart_summary_footer.dart';
import '../../../core/widgets/app_availability_calendar.dart';
import '../../rental_confirmation/presentation/bottom_sheets/change_branch_bottom_sheet.dart';
import '../domain/models/cart_item_model.dart';

class CartPage extends StatefulWidget {
  final bool isPreview;
  const CartPage({super.key, this.isPreview = false});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _loadingBranches = false;
  Future<void> _editPeriod(CartItemModel item) async {
    final result = await AppAvailabilityCalendar.show(
      context,
      currentPickup: item.startDate,
      currentReturn: item.endDate,
      branchId: item.branchId,
      deviceId: item.modelId,
      quantity: item.quantity,
    );
    if (result != null && mounted) {
      context.read<CartBloc>().add(
        CartItemPeriodOrBranchChanged(
          item.id,
          start: result['pickup'],
          end: result['return'],
        ),
      );
    }
  }

  Future<void> _editBranch(CartItemModel item) async {
    if (_loadingBranches) return;
    setState(() => _loadingBranches = true);
    try {
      final branches = await context.read<CartBloc>().repository.branchOptions(
        item.modelId,
      );
      if (!mounted) return;
      setState(() => _loadingBranches = false);
      final branch = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder:
            (_) => ChangeBranchBottomSheet(
              currentBranchId: item.branchId,
              branches: branches,
            ),
      );
      if (branch != null && mounted) {
        context.read<CartBloc>().add(
          CartItemPeriodOrBranchChanged(item.id, branchId: branch),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingBranches = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final bloc = context.read<CartBloc>();
    if (bloc.state.status == CartStatus.initial) {
      bloc.add(const CartStarted());
    }
  }

  void _showMockCheckoutNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const AppText(
              'Thông báo',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            content: const AppText(
              'Giỏ hàng đang sử dụng dữ liệu minh họa. Chưa tạo yêu cầu thuê.',
              fontSize: 14,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: AppText(
                  'Đóng',
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    String itemId,
    String itemName,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const AppText(
              'Xóa thiết bị?',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            content: AppText(
              'Bạn có chắc muốn xóa "$itemName" khỏi giỏ hàng?',
              fontSize: 14,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: AppText('Hủy', color: colorScheme.onSurfaceVariant),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: AppText(
                  'Xóa',
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      context.read<CartBloc>().add(CartItemRemoveRequested(cartItemId: itemId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<CartBloc, CartState>(
      listener: (context, state) async {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
        if (state.checkout != null) {
          final bloc = context.read<RentalBloc>();
          final ready = bloc.stream.firstWhere((r) => !r.isCreatingReservation);
          bloc.add(
            AdoptCartCheckout(
              state.checkout!,
              state.items.where((i) => i.isSelected && i.isAvailable).toList(),
            ),
          );
          final rental = await ready;
          if (!context.mounted) return;
          if (rental.maGiuCho != null) {
            await context.push(
              rental.daXacNhanThongTin
                  ? '/rental-confirmation'
                  : '/identity-verification',
            );
            if (context.mounted) {
              context.read<CartBloc>().add(const CartStarted(isRefresh: true));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  rental.reservationError ?? 'Không thể mở lượt thuê.',
                ),
              ),
            );
          }
        }
      },
      child: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          final title = 'Giỏ hàng (${state.totalLinesCount})';

          return Scaffold(
            backgroundColor: colorScheme.surfaceContainerLowest,
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              title: AppText(
                title,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              centerTitle: true,
              actions: [
                if (!state.isEmpty)
                  TextButton(
                    onPressed: () {
                      context.read<CartBloc>().add(const CartEditModeToggled());
                    },
                    child: AppText(
                      state.isEditMode ? 'Xong' : 'Sửa',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: SnapLoadingOverlay(
              loading: state.checkingOut || _loadingBranches,
              message:
                  _loadingBranches
                      ? 'Đang tải chi nhánh'
                      : 'Đang kiểm tra và giữ chỗ',
              child: _buildBody(context, state),
            ),
            bottomNavigationBar:
                state.isEmpty || state.status != CartStatus.loaded
                    ? null
                    : CartSummaryFooter(
                      summary: state.summary,
                      onCheckoutPressed: () {
                        if (widget.isPreview) {
                          _showMockCheckoutNotice(context);
                          return;
                        }
                        if (!state.checkingOut) {
                          context.read<CartBloc>().add(
                            const CartCheckoutRequested(),
                          );
                        }
                      },
                    ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, CartState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.status == CartStatus.initial ||
        (state.status == CartStatus.loading && state.items.isEmpty)) {
      return const SnapLoadingView(
        message: 'Đang tải giỏ hàng',
        size: RetroCameraLoader.large,
      );
    }

    if (state.status == CartStatus.failure && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              AppText(
                state.errorMessage ?? 'Không thể tải giỏ hàng',
                fontSize: 15,
                color: colorScheme.onSurface,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.read<CartBloc>().add(const CartStarted());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const AppText('Thử lại', color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return CartEmptyView(
        onExplorePressed: () {
          if (Navigator.of(context).canPop()) {
            context.go('/?tab=explore');
          } else {
            context.go('/?tab=explore');
          }
        },
      );
    }

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        context.read<CartBloc>().add(const CartStarted(isRefresh: true));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pageMargin,
          vertical: 12,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          for (final group in state.branchGroups) ...[
            CartBranchHeader(branchName: group.branchName),
            for (final item in group.items)
              CartItemCard(
                item: item,
                isEditMode: state.isEditMode,
                isUpdating: state.updatingItemIds.contains(item.id),
                onPeriodPressed:
                    widget.isPreview ? null : () => _editPeriod(item),
                onBranchPressed:
                    widget.isPreview ? null : () => _editBranch(item),
                onSelectionChanged: (isSelected) {
                  context.read<CartBloc>().add(
                    CartItemSelectionToggled(
                      cartItemId: item.id,
                      isSelected: isSelected,
                    ),
                  );
                },
                onQuantityChanged: (quantity) {
                  context.read<CartBloc>().add(
                    CartItemQuantityChanged(
                      cartItemId: item.id,
                      quantity: quantity,
                    ),
                  );
                },
                onDeletePressed: () {
                  _confirmDeleteItem(context, item.id, item.modelName);
                },
              ),
            const SizedBox(height: 4),
          ],

          if (widget.isPreview)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AppText(
                      'Dữ liệu minh họa — chưa đồng bộ với hệ thống.',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
