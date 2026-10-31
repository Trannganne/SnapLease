import '../../domain/entities/device_detail.dart';

class MockDeviceDetailRepository {
  Future<DeviceDetail> getDeviceDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return DeviceDetail(
      id: id,
      name: 'Sony Alpha A7 IV',
      category: 'Sony • Máy ảnh Mirrorless',
      rating: 4.8,
      reviewCount: 24,
      pricePerDay: '450.000đ',
      pricePerDayInt: 450000,
      availableQuantity: 3,
      images: [
        'assets/images/camera.png',
        'assets/images/lens.png',
        'assets/images/screen.png',
      ],
      badges: ['Full Frame', '99% Độ mới'],
      description:
          'Sony Alpha A7 IV là dòng máy ảnh mirrorless cao cấp phù hợp cho nhu cầu chụp ảnh và quay video chuyên nghiệp. Thiết bị có chất lượng hình ảnh tốt, hoạt động bền bỉ trong nhiều điều kiện.',
      deviceValue: '25.000.000đ',
      depositRate: '20%',
      estimatedDeposit: '5.000.000đ',
      pickupDate: '20/09/2026',
      pickupTime: 'Chủ nhật • 09:00',
      returnDate: '23/09/2026',
      returnTime: 'Thứ tư • 18:00',
      rentalDays: 3,
      subtotal: '1.350.000đ',
      discountPercent: 'Giảm giá 10%',
      discountAmount: '-135.000đ',
      total: '1.215.000đ',
      branches: [
        BranchAvailability(
          branchId: 'CH001',
          branchName: 'Chi nhánh Quận 1',
          address: '88 Nguyễn Du, Bến Nghé',
          availableQuantity: 2,
        ),
        BranchAvailability(
          branchId: 'CH007',
          branchName: 'Chi nhánh Quận 7',
          address: '104 Nguyễn Thị Thập, Tân Phú',
          availableQuantity: 1,
        ),
      ],
      reviews: [
        DeviceReview(
          userName: 'Nguyễn Văn A',
          date: '12/09/2026',
          rating: 5.0,
          comment: 'Máy còn mới, hoạt động tốt, hỗ trợ nhận máy nhanh.',
        ),
        DeviceReview(
          userName: 'Trần Minh K',
          date: '05/09/2026',
          rating: 4.0,
          comment: 'Thiết bị đúng mô tả, giá thuê hợp lý.',
        ),
      ],
    );
  }
}
