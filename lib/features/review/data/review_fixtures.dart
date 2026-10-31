import '../domain/models/review_detail_model.dart';
import '../domain/models/review_target_device.dart';

class ReviewFixtures {
  // 1. Target device for default / empty state (Sony Alpha A7 IV)
  static const ReviewTargetDevice defaultDevice = ReviewTargetDevice(
    contractId: 'HD-2024-001',
    detailId: 'CTHD_SONY_A74',
    deviceId: 'TB_SONY_01',
    modelId: 'DM_SONY_A74',
    modelName: 'Sony Alpha A7 IV',
    categoryName: 'MÁY ẢNH',
    brandName: 'Sony',
    branchName: 'Chi nhánh Quận 1',
    serialNumber: 'SN-88392104',
    deviceImageUrl: 'assets/images/camera.png',
    contractStatus: 'HOAN_THANH',
  );

  // 2. Second device in a multi-device contract (Lens 24-70mm GM II)
  static const ReviewTargetDevice multiDeviceItem = ReviewTargetDevice(
    contractId: 'HD-2024-001',
    detailId: 'CTHD_SONY_2470GM2',
    deviceId: 'TB_LENS_02',
    modelId: 'DM_SONY_2470GM2',
    modelName: 'Sony FE 24-70mm f/2.8 GM II',
    categoryName: 'ỐNG KÍNH',
    brandName: 'Sony',
    branchName: 'Chi nhánh Quận 1',
    serialNumber: 'SN-LENS-44129',
    deviceImageUrl: 'assets/images/camera.png',
    contractStatus: 'HOAN_THANH',
  );

  // 3. Device with very long name and branch name
  static const ReviewTargetDevice longNameDevice = ReviewTargetDevice(
    contractId: 'HD-2024-099',
    detailId: 'CTHD_LUMIX_S1H',
    deviceId: 'TB_LUMIX_01',
    modelId: 'DM_LUMIX_S1H',
    modelName:
        'Panasonic Lumix DC-S1H Mirrorless Cinema Camera Full-Frame 6K V-Log Edition Pro',
    categoryName: 'MÁY QUAY CINEMA',
    brandName: 'Panasonic',
    branchName:
        'Chi nhánh Trung tâm Phân phối Thiết bị Nhiếp ảnh SNAPLEASE TP.HCM Cơ sở 2',
    serialNumber: 'SN-99882211004488',
    deviceImageUrl: 'assets/images/camera.png',
    contractStatus: 'HOAN_THANH',
  );

  // 4. Ineligible device: contract not completed
  static const ReviewTargetDevice incompletedContractDevice =
      ReviewTargetDevice(
        contractId: 'HD-2024-015',
        detailId: 'CTHD_INCOMPLETED',
        deviceId: 'TB_CANON_09',
        modelId: 'DM_CANON_R5',
        modelName: 'Canon EOS R5',
        categoryName: 'MÁY ẢNH',
        brandName: 'Canon',
        branchName: 'Chi nhánh Quận 7',
        serialNumber: 'SN-CANON-7761',
        deviceImageUrl: 'assets/images/camera.png',
        contractStatus: 'DANG_THUE',
      );

  // 5. Pre-filled review detail for Pending state (State 5)
  static final ReviewDetailModel pendingReview = ReviewDetailModel(
    reviewId: 'REV_PENDING_001',
    detailId: 'CTHD_SONY_A74',
    rating: 4,
    comment:
        'Máy lấy nét nhanh, chống rung tốt khi quay cầm tay. Pin dùng cả buổi chụp sự kiện không vấn đề gì. Rất hài lòng với dịch vụ giao nhận máy của chi nhánh.',
    highlights: const [
      'Chất lượng hình ảnh tốt',
      'Thiết bị hoạt động ổn định',
      'Pin sử dụng tốt',
    ],
    imageUrls: const ['assets/images/camera.png'],
    reviewerName: 'Trần Minh Tâm',
    reviewerAvatar: null,
    reviewedAt: DateTime(2026, 10, 16, 14, 30),
    isVerifiedRenter: true,
    isApproved: false,
    isPublic: false,
    moderationStatus: 'AN',
    moderationNote: 'Nội dung không liên quan đến thiết bị.',
  );

  // 6. Pre-filled review detail for Approved state (State 6)
  static final ReviewDetailModel approvedReview = ReviewDetailModel(
    reviewId: 'REV_APPROVED_002',
    detailId: 'CTHD_CANON_R6M2',
    rating: 5,
    comment:
        'Thiết bị ở tình trạng rất mới, sensor sạch sẽ không có bụi. Màu da chụp chân dung cực kỳ ưng ý. Nhân viên hỗ trợ kiểm tra phụ kiện và hướng dẫn tận tình lúc nhận máy.',
    highlights: const [
      'Chất lượng hình ảnh tốt',
      'Thiết bị hoạt động ổn định',
      'Ngoại hình tốt',
      'Dễ sử dụng',
    ],
    imageUrls: const ['assets/images/camera.png', 'assets/images/camera.png'],
    reviewerName: 'Nguyễn Văn A',
    reviewerAvatar: null,
    reviewedAt: DateTime(2026, 10, 15, 9, 15),
    isVerifiedRenter: true,
    isApproved: false,
    isPublic: true,
    moderationStatus: 'CONG_KHAI',
  );

  // 7. Approved device target
  static const ReviewTargetDevice approvedDevice = ReviewTargetDevice(
    contractId: 'HD-2024-002',
    detailId: 'CTHD_CANON_R6M2',
    deviceId: 'TB_CANON_02',
    modelId: 'DM_CANON_R6M2',
    modelName: 'Canon EOS R6 Mark II',
    categoryName: 'MÁY ẢNH',
    brandName: 'Canon',
    branchName: 'Chi nhánh Quận 3',
    serialNumber: 'SN-CANON-0921',
    deviceImageUrl: 'assets/images/camera.png',
    contractStatus: 'HOAN_THANH',
  );
}
