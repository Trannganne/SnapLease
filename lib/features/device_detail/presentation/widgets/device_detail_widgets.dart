import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../domain/entities/device_detail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../rental/bloc/rental_bloc.dart';
import '../../../../core/widgets/app_availability_calendar.dart';

class DeviceImageGallery extends StatefulWidget {
  final List<String> images;
  final List<String> badges;

  const DeviceImageGallery({
    super.key,
    required this.images,
    required this.badges,
  });

  @override
  State<DeviceImageGallery> createState() => _DeviceImageGalleryState();
}

class _DeviceImageGalleryState extends State<DeviceImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AppImage(
                imageUrl: widget.images[_currentIndex],
                width: double.infinity,
                height: 240,
              ),
            ),
            if (widget.badges.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      AppText(
                        widget.badges.first,
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.badges.length > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      AppText(
                        widget.badges[1],
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(widget.images.length, (index) {
                final isSelected = index == _currentIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AppImage(
                        imageUrl: widget.images[index],
                        width: 48,
                        height: 48,
                        iconSize: 24,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Row(
              children: List.generate(
                widget.images.length,
                (index) => Container(
                  margin: const EdgeInsets.only(left: 4),
                  width: index == _currentIndex ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        index == _currentIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BasicInfoSection extends StatelessWidget {
  final DeviceDetail detail;

  const BasicInfoSection({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              detail.category,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFFFFF7E6), // Light orange background for rating
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 12),
                  SizedBox(width: 4),
                  AppText(
                    '${detail.rating} (${detail.reviewCount} đánh giá)',
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        AppText(
          detail.name,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText(
              detail.pricePerDay,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class StatusCard extends StatelessWidget {
  final int availableQuantity;

  const StatusCard({super.key, required this.availableQuantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('Tình trạng', fontWeight: FontWeight.bold),
                  AppText(
                    '$availableQuantity thiết bị khả dụng',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const AppText(
                  'Còn thiết bị',
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RentalPeriodCard extends StatelessWidget {
  final DeviceDetail detail;

  const RentalPeriodCard({super.key, required this.detail});
  
  String _getRentalDaysText(RentalState rentalState) {
    if (rentalState.pickupDate == null || rentalState.returnDate == null) {
      return 'Chưa đủ ngày';
    }
    if (rentalState.priceQuote != null) {
      return 'Thời gian thuê: ${rentalState.priceQuote!['soNgayTinhPhi']} ngày';
    }
    final diff = rentalState.returnDate!.difference(rentalState.pickupDate!).inDays;
    final displayDays = diff > 0 ? diff : 1;
    return 'Thời gian thuê: $displayDays ngày';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RentalBloc, RentalState>(
      builder: (context, rentalState) {
        final pickupDateStr =
            rentalState.pickupDate != null
                ? DateFormat('dd/MM/yyyy').format(rentalState.pickupDate!)
                : 'Chưa chọn ngày';
        final returnDateStr =
            rentalState.returnDate != null
                ? DateFormat('dd/MM/yyyy').format(rentalState.returnDate!)
                : 'Chưa chọn ngày';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  'Thời gian thuê',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 4),
                      AppText(
                        _getRentalDaysText(rentalState),
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateCard(
                    'Ngày nhận',
                    pickupDateStr,
                    rentalState.pickupDate != null ? '09:00' : '-', // Default time for now if selected
                    context,
                    onTap: () async {
                      final result = await AppAvailabilityCalendar.show(
                        context,
                        currentPickup: rentalState.pickupDate,
                        currentReturn: rentalState.returnDate,
                        branchId: rentalState.branchId,
                        deviceId: detail.id,
                        quantity: rentalState.quantity,
                      );
                      
                      if (result != null && context.mounted) {
                        context.read<RentalBloc>().add(
                          UpdateRentalPeriod(
                            pickupDate: result['pickup']!,
                            returnDate: result['return'],
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateCard(
                    'Ngày trả',
                    returnDateStr,
                    rentalState.returnDate != null ? '18:00' : '-', // Default time for now if selected
                    context,
                    onTap: () async {
                      final result = await AppAvailabilityCalendar.show(
                        context,
                        currentPickup: rentalState.pickupDate,
                        currentReturn: rentalState.returnDate,
                        branchId: rentalState.branchId,
                        deviceId: detail.id,
                        quantity: rentalState.quantity,
                      );
                      
                      if (result != null && context.mounted) {
                        context.read<RentalBloc>().add(
                          UpdateRentalPeriod(
                            pickupDate: result['pickup']!,
                            returnDate: result['return'],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  'Số lượng',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: rentalState.quantity > 1
                            ? () {
                                context.read<RentalBloc>().add(
                                      UpdateQuantity(rentalState.quantity - 1),
                                    );
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: rentalState.quantity > 1
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: AppText(
                          '${rentalState.quantity}',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      InkWell(
                        onTap: () {
                          context.read<RentalBloc>().add(
                                UpdateQuantity(rentalState.quantity + 1),
                              );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rentalState.availableQuantity != null && rentalState.availableQuantity! < rentalState.quantity)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: AppText(
                  'Số lượng không đủ. Chỉ còn ${rentalState.availableQuantity} thiết bị khả dụng.',
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDateCard(
    String title,
    String date,
    String time,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              Theme.of(
                context,
              ).colorScheme.surface, // Or a very light blue/purple
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 4),
                AppText(
                  title,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(date, fontWeight: FontWeight.bold, fontSize: 16),
            SizedBox(height: 2),
            AppText(
              time,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class RentalInfoCard extends StatelessWidget {
  final DeviceDetail detail;

  const RentalInfoCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('Thông tin thuê', fontSize: 16, fontWeight: FontWeight.bold),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            children: [
              _buildInfoRow('Giá thuê niêm yết', detail.pricePerDay, context),
              const SizedBox(height: 12),
              _buildInfoRow('Giá trị thiết bị', detail.deviceValue, context),
              const SizedBox(height: 12),
              _buildInfoRow('Tỷ lệ cọc áp dụng', detail.depositRate, context),
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppText(
                      'Tiền cọc dự kiến',
                      fontWeight: FontWeight.w600,
                    ),
                    AppText(
                      detail.estimatedDeposit,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        'Tiền cọc có thể hoàn trả nhanh chóng ngay sau khi hoàn tất kiểm tra và bàn giao thiết bị.',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(
          label,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        AppText(value, fontWeight: FontWeight.w600, fontSize: 14),
      ],
    );
  }
}

class DescriptionSection extends StatefulWidget {
  final String description;

  const DescriptionSection({super.key, required this.description});

  @override
  State<DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<DescriptionSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('Mô tả', fontSize: 16, fontWeight: FontWeight.bold),
        SizedBox(height: 8),
        AppText(
          widget.description,
          maxLines: _isExpanded ? null : 3,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                _isExpanded ? 'Thu gọn' : 'Xem thêm',
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BranchAvailabilitySection extends StatelessWidget {
  final List<BranchAvailability> branches;

  const BranchAvailabilitySection({super.key, required this.branches});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText('Khả dụng tại', fontSize: 16, fontWeight: FontWeight.bold),
            AppText(
              '${branches.length} cơ sở',
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...branches.map((branch) => _buildBranchCard(branch, context)),
      ],
    );
  }

  Widget _buildBranchCard(BranchAvailability branch, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.storefront,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(branch.branchName, fontWeight: FontWeight.bold),
                AppText(
                  branch.address,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppText(
              'Còn ${branch.availableQuantity} máy',
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewSection extends StatelessWidget {
  final List<DeviceReview> reviews;
  final double rating;
  final int reviewCount;

  const ReviewSection({
    super.key,
    required this.reviews,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppText('Đánh giá', fontSize: 16, fontWeight: FontWeight.bold),
                SizedBox(width: 8),
                AppText(
                  '$rating / 5 • $reviewCount đánh giá',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                // TODO: View all reviews
              },
              child: AppText(
                'Xem tất cả',
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reviews.map((review) => _buildReviewCard(review, context)),
      ],
    );
  }

  Widget _buildReviewCard(DeviceReview review, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    child: AppText(
                      review.userName.isNotEmpty
                          ? review.userName[0].toUpperCase()
                          : 'U',
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  AppText(review.userName, fontWeight: FontWeight.bold),
                ],
              ),
              AppText(
                review.date,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          SizedBox(height: 8),
          AppText(
            review.comment,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class PriceSummaryCard extends StatelessWidget {
  final DeviceDetail detail;

  const PriceSummaryCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RentalBloc, RentalState>(
      builder: (context, rentalState) {
        return Container(
          padding: EdgeInsets.all(16),
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
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const AppText(
                    'Tạm tính',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (rentalState.pickupDate == null || rentalState.returnDate == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: AppText(
                      'Chọn ngày thuê để xem chi phí',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (rentalState.isChecking)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (rentalState.checkError != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: AppText(
                      'Lỗi: ${rentalState.checkError}',
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (rentalState.priceQuote != null)
                Column(
                  children: [
                    _buildPriceRow(
                      'Thời gian thuê',
                      '${rentalState.priceQuote!['soNgayTinhPhi']} ngày × ${rentalState.quantity} thiết bị',
                      context,
                    ),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Tiền thuê',
                      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(rentalState.priceQuote!['tongTienThue']),
                      context,
                    ),
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Tiền cọc',
                      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(rentalState.priceQuote!['tongTienCoc']),
                      context,
                    ),
                    if (rentalState.priceQuote!['phanTramGiamGia'] != null && rentalState.priceQuote!['phanTramGiamGia'] > 0) ...[
                      const SizedBox(height: 8),
                      _buildPriceRow(
                        'Giảm giá',
                        '-${rentalState.priceQuote!['phanTramGiamGia']}%',
                        context,
                        valueColor: Colors.green,
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    _buildPriceRow(
                      'Tạm tính',
                      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(
                        (rentalState.priceQuote!['tongTienThue'] as num) + (rentalState.priceQuote!['tongTienCoc'] as num)
                      ),
                      context,
                      isTotal: true,
                    ),
                  ],
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: AppText(
                      'Chưa có báo giá',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceRow(String label, String value, BuildContext context,
      {bool isTotal = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        AppText(
          label,
          color: isTotal
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          fontSize: isTotal ? 16 : 14,
        ),
        AppText(
          value,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          color: valueColor ?? Theme.of(context).colorScheme.onSurface,
          fontSize: isTotal ? 18 : 14,
        ),
      ],
    );
  }
}

class DeviceDetailBottomBar extends StatelessWidget {
  final String pricePerDay;
  final RentalState rentalState;
  final VoidCallback? onContinue;

  const DeviceDetailBottomBar({
    super.key,
    required this.pricePerDay,
    required this.rentalState,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'Tạm tính / ngày';
    String valueStr = pricePerDay
        .replaceAll('đ/ngày', '')
        .replaceAll('/ngày', '')
        .replaceAll('đ', '');
    String unit = 'đ/ngày';
    Widget priceWidget;

    if (rentalState.isChecking) {
      priceWidget = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      title = 'Đang tính...';
    } else if (rentalState.checkError != null) {
      priceWidget = AppText(
        'Lỗi',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.error,
      );
      title = 'Báo giá';
      unit = '';
    } else if (rentalState.priceQuote != null) {
      title = 'Tạm tính';
      valueStr = NumberFormat.currency(locale: 'vi_VN', symbol: '')
          .format(rentalState.priceQuote!['tongTienThue'])
          .trim();
      unit = 'đ';
      priceWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            valueStr,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          AppText(
            unit,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      );
    } else {
      priceWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            valueStr,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          AppText(
            unit,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      );
    }

    return Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(
                  title,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                priceWidget,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              text: 'Tiếp tục thuê',
              onPressed: onContinue,
              isLoading: rentalState.isCreatingReservation,
            ),
          ),
        ],
      ),
    );
  }
}
