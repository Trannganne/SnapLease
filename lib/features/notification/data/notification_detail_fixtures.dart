import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';
import 'package:rentcam/features/contract/domain/models/handover_models.dart';
import 'package:rentcam/features/contract/domain/models/contract_payment_summary.dart';

class NotificationDetailDemoFixture {
  final String key;
  final String label;
  final String variantCode; // 'A', 'B', 'C', 'D'
  final NotificationItemModel notification;
  final ContractModel? contract;
  final Map<String, dynamic>? metadata;

  const NotificationDetailDemoFixture({
    required this.key,
    required this.label,
    required this.variantCode,
    required this.notification,
    this.contract,
    this.metadata,
  });
}

class NotificationDetailFixtures {
  static final DateTime now = DateTime.now();

  static List<NotificationDetailDemoFixture> get allFixtures => [
        variantCompleted,
        completedNoTarget,
        completedLoading,
        completedError,
        completedNotFound,
        completedMultiDevices,
        completedStatusMismatch,
        variantA,
        variantB,
        variantC,
        variantD,
        variantAExpired,
        variantDOverdue,
        multiDevicesFixture,
        noContractFixture,
      ];

  // 1. Variant A: Chờ ký
  static NotificationDetailDemoFixture get variantA => NotificationDetailDemoFixture(
        key: 'variant_a',
        label: 'Biến thể A: Chờ ký',
        variantCode: 'A',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-A',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đang chờ ký',
          content:
              'Hợp đồng thuê thiết bị HD000125 đã được khởi tạo thành công từ phiên đặt thuê của bạn. Vui lòng hoàn tất ký điện tử trong vòng 15 phút để giữ trọn vẹn thiết bị.',
          sentAt: DateTime(now.year, now.month, now.day, 10, 15),
          isRead: false,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000125',
          actionText: 'Ký hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD000125',
          date: DateTime(now.year, now.month, now.day),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: DateTime(2026, 10, 20),
          returnDate: DateTime(2026, 10, 23),
          rentalDays: 3,
          branchName: 'Hub Quận 1',
          rentalTotal: 1500000,
          deposit: 2000000,
          totalAmount: 3500000,
          status: 'CHO_KY',
          signingMethod: 'Ký điện tử & Xác thực OTP',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
        ),
        metadata: {
          'insurance': 'Gói bảo hiểm SnapCare+ • 3 ngày',
          'depositText': 'Tiền cọc: 2.000.000đ',
          'signingDeadline': '10:30 (còn 15 phút)',
          'isExpired': false,
        },
      );

  // 2. Variant B: Đã ký
  static NotificationDetailDemoFixture get variantB => NotificationDetailDemoFixture(
        key: 'variant_b',
        label: 'Biến thể B: Đã ký',
        variantCode: 'B',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-B',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã được ký thành công',
          content:
              'Chữ ký số và xác thực OTP cho hợp đồng HD000123 đã được chứng thực hợp lệ. Bạn có thể mở xem lại toàn bộ điều khoản hợp đồng đã ký kèm chứng thư số bất kỳ lúc nào.',
          sentAt: DateTime(2026, 10, 16, 11, 20),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000123',
          actionText: 'Xem hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD000123',
          date: DateTime(2026, 10, 16),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony A7 IV + Lens 24-70mm GM II',
          deviceModel: 'Combo A7M4',
          quantity: 2,
          pricePerDay: 850000,
          pickupDate: DateTime(2026, 10, 18),
          returnDate: DateTime(2026, 10, 22),
          rentalDays: 4,
          branchName: 'Hub Quận 1',
          rentalTotal: 3400000,
          deposit: 2000000,
          totalAmount: 5400000,
          status: 'DA_KY',
          signedAt: DateTime(2026, 10, 16, 11, 20),
          signedPdfAvailable: true,
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
            BookedContractDevice(
              modelId: 'DM02',
              name: 'Lens Sony FE 24-70mm F2.8 GM II',
              quantity: 1,
              pricePerDay: 350000,
            ),
          ],
          payments: const ContractPaymentSummary(
            complete: true,
            receipts: [
              ContractPaymentReceipt(
                id: 'TT01',
                type: 'TIEN_COC',
                status: 'THANH_CONG',
                method: 'CHUYEN_KHOAN',
                amount: 2000000,
              ),
            ],
          ),
        ),
        metadata: {
          'comboTitle': 'Sony A7 IV + Lens 24-70mm GM II',
          'accessories': 'Kèm 02 pin dự phòng & thẻ nhớ CFexpress',
          'rentalPeriod': '18/10/2026 - 22/10/2026 (4 ngày)',
          'depositStatus': 'Đã thanh toán (2.000.000đ)',
        },
      );

  // 3. Variant C: Đang thuê / Bắt đầu thuê
  static NotificationDetailDemoFixture get variantC => NotificationDetailDemoFixture(
        key: 'variant_c',
        label: 'Biến thể C: Đang thuê',
        variantCode: 'C',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-C',
          rawType: 'BAN_GIAO',
          title: 'Hợp đồng đã bắt đầu',
          content:
              'Thiết bị đã được bàn giao thành công tại Hub Quận 1. Thời hạn thuê của hợp đồng HD000120 chính thức có hiệu lực từ hôm nay. Chúc bạn có những thước phim tuyệt vời!',
          sentAt: DateTime(now.year, now.month, now.day, 8, 30),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000120',
          actionText: 'Theo dõi hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD000120',
          date: DateTime(now.year, now.month, now.day),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Canon EOS R5 Mirrorless...',
          deviceModel: 'EOS R5',
          quantity: 1,
          pricePerDay: 750000,
          pickupDate: DateTime(now.year, now.month, now.day, 8, 30),
          returnDate: DateTime(now.year, now.month, now.day + 3, 18, 0),
          rentalDays: 3,
          branchName: 'Hub Quận 1',
          rentalTotal: 2250000,
          deposit: 3000000,
          totalAmount: 5250000,
          status: 'DANG_THUE',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM03',
              name: 'Canon EOS R5 Mirrorless...',
              quantity: 1,
              pricePerDay: 750000,
            ),
          ],
        ),
        metadata: {
          'lensInfo': 'Kèm Lens Canon RF 24-70mm f/2.8L',
          'insuranceNote': 'Bảo hiểm toàn diện kích hoạt',
          'actualStart': '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} • 08:30',
          'expectedReturn': '${(now.day + 3).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} • 18:00',
          'condition': 'Mới 98% (Đã ký biên bản bàn giao)',
        },
      );

  // 4. Variant D: Sắp hết hạn trả
  static NotificationDetailDemoFixture get variantD => NotificationDetailDemoFixture(
        key: 'variant_d',
        label: 'Biến thể D: Sắp đến hạn trả',
        variantCode: 'D',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-D',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng sắp đến hạn trả',
          content:
              'Hợp đồng thuê thiết bị HD000118 sẽ kết thúc lúc 18:00 hôm nay. Vui lòng chuẩn bị đầy đủ thiết bị và phụ kiện để bàn giao hoàn tất tại Hub.',
          sentAt: DateTime(now.year, now.month, now.day, 14, 0),
          isRead: false,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000118',
          actionText: 'Xem hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD000118',
          date: DateTime(now.year, now.month, now.day - 3),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: DateTime(now.year, now.month, now.day - 3),
          returnDate: DateTime(now.year, now.month, now.day, 18, 0),
          rentalDays: 3,
          branchName: 'Hub Q1 (120 Nguyễn Huệ)',
          rentalTotal: 1500000,
          deposit: 2000000,
          totalAmount: 3500000,
          status: 'CHO_HOAN_TRA',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
        ),
        metadata: {
          'rentFrom': 'Thuê từ: ${(now.day - 3).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
          'returnLocation': 'Điểm trả: Hub Q1 (120 Nguyễn Huệ)',
          'depositNotice': '2.000.000đ (sau khi kiểm tra thiết bị)',
          'dueTime': DateTime(now.year, now.month, now.day, 18, 0),
          'isOverdue': false,
        },
      );

  // 5. Edge Case: Variant A Expired (Hết hạn ký)
  static NotificationDetailDemoFixture get variantAExpired => NotificationDetailDemoFixture(
        key: 'variant_a_expired',
        label: 'Ca biên: Chờ ký (Đã hết hạn)',
        variantCode: 'A',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-A-EXPIRED',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đang chờ ký',
          content:
              'Hợp đồng thuê thiết bị HD000125 đã được khởi tạo thành công từ phiên đặt thuê của bạn. Vui lòng hoàn tất ký điện tử trong vòng 15 phút để giữ trọn vẹn thiết bị.',
          sentAt: now.subtract(const Duration(minutes: 45)),
          isRead: false,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000125',
        ),
        contract: ContractModel(
          contractId: 'HD000125',
          date: now.subtract(const Duration(minutes: 45)),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: now.add(const Duration(days: 1)),
          returnDate: now.add(const Duration(days: 4)),
          rentalDays: 3,
          branchName: 'Hub Quận 1',
          rentalTotal: 1500000,
          deposit: 2000000,
          totalAmount: 3500000,
          status: 'DA_HUY', // expired contract status
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
        ),
        metadata: {
          'insurance': 'Gói bảo hiểm SnapCare+',
          'signingDeadline': 'Đã quá thời hạn 15 phút',
          'isExpired': true,
        },
      );

  // 6. Edge Case: Variant D Overdue (Quá hạn trả)
  static NotificationDetailDemoFixture get variantDOverdue => NotificationDetailDemoFixture(
        key: 'variant_d_overdue',
        label: 'Ca biên: Sắp đến hạn (Đã quá hạn)',
        variantCode: 'D',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-VAR-D-OVERDUE',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng sắp đến hạn trả',
          content:
              'Hợp đồng thuê thiết bị HD000118 đã đến hạn hoàn trả. Vui lòng nhanh chóng hoàn tất trả máy tại Hub để tránh phát sinh phụ phí trễ hạn.',
          sentAt: now.subtract(const Duration(hours: 3)),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000118',
        ),
        contract: ContractModel(
          contractId: 'HD000118',
          date: now.subtract(const Duration(days: 3)),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: now.subtract(const Duration(days: 3)),
          returnDate: now.subtract(const Duration(hours: 2)),
          rentalDays: 3,
          branchName: 'Hub Q1 (120 Nguyễn Huệ)',
          rentalTotal: 1500000,
          deposit: 2000000,
          totalAmount: 3500000,
          status: 'CHO_HOAN_TRA',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
        ),
        metadata: {
          'dueTime': now.subtract(const Duration(hours: 2)),
          'isOverdue': true,
          'depositNotice': '2.000.000đ (đang đối soát phụ phí trễ hạn)',
        },
      );

  // 7. Edge Case: Nhiều thiết bị & Tên dài
  static NotificationDetailDemoFixture get multiDevicesFixture => NotificationDetailDemoFixture(
        key: 'multi_devices',
        label: 'Ca biên: Nhiều thiết bị & Tên rất dài',
        variantCode: 'B',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-MULTI-DEVICES',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã được ký thành công với danh mục gói combo chuyên nghiệp',
          content:
              'Hợp đồng HD000999 gồm nhiều thiết bị máy ảnh và ống kính cao cấp đã được xác nhận chữ ký điện tử. Quý khách vui lòng đến Hub theo lịch hẹn để nhận bàn giao toàn bộ gói thiết bị.',
          sentAt: now.subtract(const Duration(hours: 1)),
          isRead: false,
          targetType: NotificationTargetType.contract,
          targetId: 'HD000999',
        ),
        contract: ContractModel(
          contractId: 'HD000999',
          date: now,
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A1 II Flagship Cinema Camera Full Frame',
          deviceModel: 'ILCE-1M2',
          quantity: 3,
          pricePerDay: 2500000,
          pickupDate: now.add(const Duration(days: 2)),
          returnDate: now.add(const Duration(days: 6)),
          rentalDays: 4,
          branchName: 'Hub Quận 1 (120 Nguyễn Huệ, Phường Bến Nghé)',
          rentalTotal: 10000000,
          deposit: 15000000,
          totalAmount: 25000000,
          status: 'DA_KY',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A1 II Flagship Cinema Camera Full Frame 8K',
              quantity: 1,
              pricePerDay: 1500000,
            ),
            BookedContractDevice(
              modelId: 'DM02',
              name: 'Sony FE 70-200mm F2.8 GM OSS II Telephoto Zoom Lens',
              quantity: 1,
              pricePerDay: 600000,
            ),
            BookedContractDevice(
              modelId: 'DM03',
              name: 'DJI Ronin RS3 Pro Gimbal Stabilizer Combo Kit',
              quantity: 1,
              pricePerDay: 400000,
            ),
          ],
        ),
        metadata: {
          'comboTitle': 'Gói thiết bị quay phim điện ảnh đa thiết bị',
          'accessories': 'Kèm 04 pin sạc nhanh, 02 hộp chống sốc Pelican & thẻ CFexpress Type A 160GB',
          'rentalPeriod': '20/10/2026 - 24/10/2026 (4 ngày)',
          'depositStatus': 'Đã thanh toán (15.000.000đ)',
        },
      );

  // 8. Edge Case: Không có hợp đồng liên kết (Chỉ có nội dung văn bản)
  static NotificationDetailDemoFixture get noContractFixture => NotificationDetailDemoFixture(
        key: 'no_contract',
        label: 'Ca biên: Không có hợp đồng liên kết',
        variantCode: 'GENERIC',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-NO-CONTRACT',
          rawType: 'XAC_MINH_GIAY_TO',
          title: 'Hồ sơ xác minh danh tính đã được phê duyệt',
          content:
              'Chào bạn, hồ sơ CCCD và thông tin xác thực danh tính cá nhân của bạn đã được kiểm duyệt hợp lệ trên hệ thống SNAPLEASE. Giờ đây bạn có thể thoải mái đặt thuê các dòng máy ảnh cao cấp trên ứng dụng.',
          sentAt: now.subtract(const Duration(days: 2)),
          isRead: true,
          targetType: NotificationTargetType.none,
          targetId: null,
        ),
        contract: null,
      );

  // 9. Biến thể Hoàn tất (Có hợp đồng liên kết và dữ liệu nhận/trả thực tế)
  static NotificationDetailDemoFixture get variantCompleted => NotificationDetailDemoFixture(
        key: 'variant_completed',
        label: 'Hoàn tất: Đầy đủ liên kết & dữ liệu',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-COMPLETED',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content:
              'Hợp đồng HD001 đã hoàn tất việc thuê và hoàn trả thiết bị tại SNAPLEASE Hub. Cảm ơn quý khách đã tin tưởng và đồng hành cùng dịch vụ.',
          sentAt: DateTime(2026, 8, 7, 19, 0),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD001',
          actionText: 'Xem chi tiết hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD001',
          date: DateTime(2026, 8, 1),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: DateTime(2026, 8, 1),
          returnDate: DateTime(2026, 8, 7),
          rentalDays: 6,
          branchName: 'SNAPLEASE Hub Quận 1',
          rentalTotal: 3000000,
          deposit: 2000000,
          totalAmount: 5000000,
          status: 'HOAN_THANH',
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
          assignedDevices: [
            AssignedContractDevice(
              detailId: 'CTHD001',
              deviceId: 'TB001',
              modelId: 'DM01',
              serial: 'SN-A7M4-8891',
              handedOverAt: DateTime(2026, 8, 1, 9, 30),
              returnedAt: DateTime(2026, 8, 7, 18, 20),
            ),
          ],
        ),
        metadata: {
          'actualReturn': '07/08/2026 • 18:20',
        },
      );

  // 10. Hoàn tất: Dữ liệu thật DTO thiếu target (như API hiện tại)
  static NotificationDetailDemoFixture get completedNoTarget => NotificationDetailDemoFixture(
        key: 'completed_no_target',
        label: 'Hoàn tất: Dữ liệu thật thiếu liên kết',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'TBao001',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content: 'Hợp đồng HD001 đã hoàn thành',
          sentAt: DateTime(2026, 8, 7, 19, 0),
          isRead: true,
          targetType: NotificationTargetType.none,
          targetId: null,
        ),
        contract: null,
      );

  // 11. Hoàn tất: Đang tải hợp đồng
  static NotificationDetailDemoFixture get completedLoading => NotificationDetailDemoFixture(
        key: 'completed_loading',
        label: 'Hoàn tất: Đang tải hợp đồng',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'DEMO-COMPLETED-LOADING',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content:
              'Hợp đồng HD001 đã hoàn tất việc thuê và hoàn trả thiết bị tại SNAPLEASE Hub. Cảm ơn quý khách đã tin tưởng và đồng hành cùng dịch vụ.',
          sentAt: DateTime(2026, 8, 7, 19, 0),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD001',
          actionText: 'Xem chi tiết hợp đồng',
        ),
        contract: null,
        metadata: {
          'contractLoading': true,
        },
      );

  // 12. Hoàn tất: Tải hợp đồng lỗi (có thử lại)
  static NotificationDetailDemoFixture get completedError => NotificationDetailDemoFixture(
        key: 'completed_error',
        label: 'Hoàn tất: Tải hợp đồng lỗi (có thử lại)',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'DEMO-COMPLETED-ERROR',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content:
              'Hợp đồng HD001 đã hoàn tất việc thuê và hoàn trả thiết bị tại SNAPLEASE Hub. Cảm ơn quý khách đã tin tưởng và đồng hành cùng dịch vụ.',
          sentAt: DateTime(2026, 8, 7, 19, 0),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD001',
          actionText: 'Xem chi tiết hợp đồng',
        ),
        contract: null,
        metadata: {
          'contractError': 'Không thể kết nối đến máy chủ SNAPLEASE (Mã lỗi: TIMEOUT_504)',
        },
      );

  // 13. Hoàn tất: Hợp đồng không tồn tại/không có quyền truy cập
  static NotificationDetailDemoFixture get completedNotFound => NotificationDetailDemoFixture(
        key: 'completed_not_found',
        label: 'Hoàn tất: Không có quyền/Hợp đồng không tồn tại',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'DEMO-COMPLETED-NOT-FOUND',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content: 'Hợp đồng HD999 đã hoàn thành',
          sentAt: DateTime(2026, 8, 7, 19, 0),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD999',
          actionText: 'Xem chi tiết hợp đồng',
        ),
        contract: null,
      );

  // 14. Hoàn tất: Nhiều thiết bị, tên dài, thiếu ảnh
  static NotificationDetailDemoFixture get completedMultiDevices => NotificationDetailDemoFixture(
        key: 'completed_multi_devices',
        label: 'Hoàn tất: Nhiều thiết bị, tên dài, thiếu ảnh',
        variantCode: 'HOAN_THANH',
        notification: NotificationItemModel(
          id: 'DEMO-COMPLETED-MULTI-DEVICE',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã hoàn thành',
          content:
              'Hợp đồng HD002 gồm bộ thân máy và ống kính chuyên dụng đã hoàn tất việc kiểm tra và hoàn trả tại Hub.',
          sentAt: DateTime(2026, 8, 8, 17, 30),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD002',
          actionText: 'Xem chi tiết hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD002',
          date: DateTime(2026, 8, 2),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Bộ máy ảnh Sony FX3 Cinema Line + Sony FE 24-70mm F2.8 GM II',
          deviceModel: 'FX3-COMBO',
          quantity: 2,
          pricePerDay: 1200000,
          pickupDate: DateTime(2026, 8, 2),
          returnDate: DateTime(2026, 8, 8),
          rentalDays: 6,
          branchName: 'SNAPLEASE Hub Cầu Giấy - Hà Nội',
          rentalTotal: 7200000,
          deposit: 10000000,
          totalAmount: 17200000,
          status: 'HOAN_THANH',
          deviceImageUrl: null, // Thiếu ảnh để kiểm tra placeholder
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM_FX3',
              name: 'Sony FX3 Full-Frame Cinema Line Camera Body',
              quantity: 1,
              pricePerDay: 800000,
            ),
            BookedContractDevice(
              modelId: 'DM_2470GM2',
              name: 'Ống kính Sony FE 24-70mm F2.8 GM II Zoom Lens Nano AR II',
              quantity: 1,
              pricePerDay: 400000,
            ),
          ],
          assignedDevices: [
            AssignedContractDevice(
              detailId: 'CTHD002_1',
              deviceId: 'TB_FX3_01',
              modelId: 'DM_FX3',
              serial: 'SN-FX3-9921',
              handedOverAt: DateTime(2026, 8, 2, 8, 30),
              returnedAt: DateTime(2026, 8, 8, 17, 15),
            ),
            AssignedContractDevice(
              detailId: 'CTHD002_2',
              deviceId: 'TB_2470_01',
              modelId: 'DM_2470GM2',
              serial: 'SN-GM2-4412',
              handedOverAt: DateTime(2026, 8, 2, 8, 30),
              returnedAt: DateTime(2026, 8, 8, 17, 15),
            ),
          ],
        ),
        metadata: {
          'actualReturn': '08/08/2026 • 17:15',
        },
      );

  // 15. Ca biên: Sự kiện cũ vs Trạng thái hiện tại khác nhau
  static NotificationDetailDemoFixture get completedStatusMismatch => NotificationDetailDemoFixture(
        key: 'completed_status_mismatch',
        label: 'Ca biên: Sự kiện cũ vs Trạng thái hiện tại khác nhau',
        variantCode: 'STATUS_MISMATCH',
        notification: NotificationItemModel(
          id: 'DEMO-PREVIEW-STATUS-MISMATCH',
          rawType: 'HOP_DONG',
          title: 'Hợp đồng đã được ký thành công',
          content:
              'Hợp đồng HD001 đã được ký điện tử thành công. Quý khách vui lòng đến Hub nhận bàn giao đúng hẹn.',
          sentAt: DateTime(2026, 8, 1, 9, 0),
          isRead: true,
          targetType: NotificationTargetType.contract,
          targetId: 'HD001',
          actionText: 'Xem hợp đồng',
        ),
        contract: ContractModel(
          contractId: 'HD001',
          date: DateTime(2026, 8, 1),
          lessorName: 'CÔNG TY SNAPLEASE VIỆT NAM',
          lessorAddress: '120 Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
          lessorPhone: '0901234567',
          lesseeName: 'Nguyễn Văn A',
          lesseeId: '079201001234',
          lesseePhone: '0912345678',
          deviceName: 'Sony Alpha A7 IV Body',
          deviceModel: 'ILCE-7M4',
          quantity: 1,
          pricePerDay: 500000,
          pickupDate: DateTime(2026, 8, 1),
          returnDate: DateTime(2026, 8, 7),
          rentalDays: 6,
          branchName: 'SNAPLEASE Hub Quận 1',
          rentalTotal: 3000000,
          deposit: 2000000,
          totalAmount: 5000000,
          status: 'HOAN_THANH', // Hợp đồng đã hoàn thành trong khi sự kiện cũ là đã ký
          bookedDevices: const [
            BookedContractDevice(
              modelId: 'DM01',
              name: 'Sony Alpha A7 IV Body',
              quantity: 1,
              pricePerDay: 500000,
            ),
          ],
          assignedDevices: [
            AssignedContractDevice(
              detailId: 'CTHD001',
              deviceId: 'TB001',
              modelId: 'DM01',
              serial: 'SN-A7M4-8891',
              handedOverAt: DateTime(2026, 8, 1, 9, 30),
              returnedAt: DateTime(2026, 8, 7, 18, 20),
            ),
          ],
        ),
        metadata: {
          'actualReturn': '07/08/2026 • 18:20',
        },
      );
}
