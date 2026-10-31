# SNAPLEASE Mobile - Handoff & Tài liệu Kỹ thuật: Phân hệ Thông báo (Notification)

## 1. Tổng quan phân hệ
Phân hệ **Thông báo** cung cấp giao diện quản lý và theo dõi các sự kiện trong vòng đời thuê thiết bị máy ảnh trên ứng dụng SNAPLEASE:
- **Danh sách thông báo (`NotificationPage`)**: Hỗ trợ 4 bộ lọc ("Tất cả", "Chưa đọc", "Hợp đồng", "Thanh toán"), nhóm thời gian ("HÔM NAY", "HÔM QUA", "TRƯỚC ĐÓ"), badge số lượng động từ dữ liệu thật, pull-to-refresh, tải tiếp phân trang và thẻ bảo chứng tĩnh "Trung tâm xác thực SNAPLEASE".
- **Chi tiết thông báo (`NotificationDetailPage`)**: Trình bày nội dung chi tiết theo từng loại sự kiện, thẻ tóm tắt hợp đồng/thiết bị liên quan (mã hợp đồng, serial thiết bị, thời gian, chi nhánh), thẻ cảnh báo hoàn trả khi quá hạn/sắp đến hạn, nút hành động cố định (CTA) tương ứng với trạng thái nghiệp vụ.
- **Bản xem trước & thử nghiệm (`NotificationPreviewPage`)**: Trang preview độc lập phục vụ kiểm thử giao diện các biến thể (Chờ ký, Đã ký, Đang thuê, Sắp đến hạn trả, Hoàn tất hợp đồng, Không có hợp đồng liên kết).

---

## 2. Tình trạng dữ liệu & Giới hạn hiện tại (Lưu ý quan trọng)

> [!WARNING]
> **Dữ liệu thật hiện thiếu liên kết đối tượng (targetId, contractId, paymentId)**:
> Model `ThongBao` trong cơ sở dữ liệu và DTO trả về từ endpoint `GET /api/thong-bao` hiện chỉ có 7 trường: `maThongBao`, `maTaiKhoan`, `loai`, `tieuDe`, `noiDung`, `thoiGianGui`, `daDoc`.
> Backend chưa cung cấp trường khóa ngoại hoặc siêu dữ liệu đối tượng liên kết (như `maHopDong`, `maThanhToan`).
> Khi chạy với dữ liệu thật, nếu thông báo không có `targetId`, giao diện sẽ hiển thị đầy đủ thông tin nội dung văn bản nhưng **không dựng card hợp đồng giả lập** và **không hiển thị nút điều hướng sai lệch**.

> [!NOTE]
> **Bản xem trước & Thử nghiệm sử dụng Fixture**:
> Các kịch bản phong phú (Variant A - Chờ ký, Variant B - Đã ký, Variant C - Đang thuê, Variant D - Sắp đến hạn trả, Variant Hoàn tất) được cung cấp qua nguồn dữ liệu demo tách biệt (`NotificationDetailFixtures`, `MockNotificationRepository`, `NotificationDemoData`) phục vụ kiểm thử và xem trước, **tuyệt đối không âm thầm fallback sang demo khi API thật lỗi**.

> [!IMPORTANT]
> **Chưa tích hợp push notification qua Firebase Cloud Messaging (FCM)**:
> Lượt này tập trung hoàn thiện giao diện ứng dụng, tương tác lọc, chi tiết và đồng bộ trạng thái đọc/chưa đọc qua API `GET /api/thong-bao` và `PUT /api/thong-bao/{id}/da-doc`. Hạ tầng nhận push notification thời gian thực (FCM background/foreground handler) chưa được cài đặt trong lượt này.

> [!IMPORTANT]
> **Yêu cầu ẩn/xác nhận giữ chỗ còn chờ Backend**:
> Nghiệp vụ liên quan đến trạng thái xác nhận hoặc ẩn giữ chỗ (`GIU_CHO`) sau khi hết hạn cần bổ sung thêm endpoint/trường dữ liệu nghiệp vụ phía Backend API trước khi gắn logic hoàn chỉnh trên Mobile.

---

## 3. Kiến trúc luồng dữ liệu & Component

Theo quy chuẩn dự án SNAPLEASE:
```
UI (NotificationPage / NotificationDetailPage)
  ↓
Bloc / Cubit (NotificationBloc / NotificationDetailCubit)
  ↓
Repository (NotificationRepository -> DioNotificationRepository / MockNotificationRepository)
  ↓
API Client (Dio kèm Bearer token qua TokenStorage)
```

### Danh sách file triển khai:
- **Domain**:
  - `lib/features/notification/domain/models/notification_item_model.dart`: Entity `NotificationItemModel`, enum `NotificationCategory`, `NotificationTargetType`.
- **Data**:
  - `lib/features/notification/data/repositories/notification_repository.dart`: Interface `NotificationRepository`, `DioNotificationRepository`, `MockNotificationRepository`, `NotificationDemoData`.
  - `lib/features/notification/data/notification_detail_fixtures.dart`: Fixture dữ liệu chi tiết phục vụ test và preview.
- **Bloc / Cubit**:
  - `lib/features/notification/bloc/notification_bloc.dart`: Quản lý danh sách, phân trang, lọc, nhóm ngày, đánh dấu đã đọc.
  - `lib/features/notification/bloc/notification_event.dart`, `notification_state.dart`.
  - `lib/features/notification/bloc/notification_detail_cubit.dart`, `notification_detail_state.dart`: Quản lý dữ liệu chi tiết và hợp đồng liên kết.
- **Presentation**:
  - `lib/features/notification/presentation/notification_page.dart`: Màn hình danh sách thông báo.
  - `lib/features/notification/presentation/notification_detail_page.dart`: Màn hình chi tiết thông báo.
  - `lib/features/notification/presentation/notification_preview_page.dart`: Màn hình preview các biến thể.
  - `lib/features/notification/presentation/widgets/notification_card.dart`: Thẻ thông báo dùng chung.
  - `lib/features/notification/presentation/widgets/notification_filter_chips.dart`: Hàng chip lọc có badge.
  - `lib/features/notification/presentation/widgets/notification_empty_view.dart`: Trạng thái trống.
  - `lib/features/notification/presentation/widgets/notification_security_card.dart`: Thẻ trung tâm xác thực SNAPLEASE.
  - `lib/features/notification/presentation/widgets/notification_detail_summary_card.dart`: Thẻ tóm tắt chi tiết.
  - `lib/features/notification/presentation/widgets/notification_detail_content_card.dart`: Thẻ nội dung chi tiết.
  - `lib/features/notification/presentation/widgets/notification_related_contract_card.dart`: Thẻ thông tin hợp đồng liên quan.
  - `lib/features/notification/presentation/widgets/notification_return_warning_card.dart`: Thẻ cảnh báo hoàn trả.
  - `lib/features/notification/presentation/widgets/notification_demo_banner.dart`: Banner thông báo môi trường preview.

---

## 4. Kiểm thử đã thực hiện
1. **Unit & Widget Test Danh sách (`test/notification_feature_test.dart`)**:
   - 12/12 test vượt qua: Phân tích DTO, phân loại danh mục, tính badge, phân nhóm ngày, 5 trạng thái hiển thị (Tất cả, Chưa đọc, Hợp đồng, Thanh toán, Trống), đánh dấu đã đọc.
2. **Unit & Widget Test Chi tiết (`test/notification_detail_test.dart`)**:
   - 14/14 test vượt qua: Kiểm tra 4 biến thể chính (A, B, C, D) và biến thể Hoàn tất, xử lý khi thiếu hợp đồng liên kết, lỗi tải hợp đồng, quá hạn, text scale factor 1.4 không tràn layout.
