# API bổ sung cho ứng dụng khách hàng

## Hồ sơ cá nhân

- `GET /api/khach-thue/cua-toi`: đọc hồ sơ đầy đủ của tài khoản đang đăng nhập.
- `PUT /api/khach-thue/cua-toi`: cập nhật họ tên, số điện thoại, email, địa chỉ, ngày sinh, giới tính và quốc tịch.

Khách không thể cập nhật CCCD, ngày cấp, nơi cấp hoặc trạng thái xác minh qua API này. Sau khi hồ sơ đã xác minh, họ tên, ngày sinh, giới tính và quốc tịch cũng bị khóa; khách vẫn có thể cập nhật số điện thoại, email và địa chỉ.

## Khám phá dòng máy

`GET /api/dong-may` hỗ trợ thêm:

- `giaTu`, `giaDen`: khoảng giá thuê ngày, lớn hơn hoặc bằng 0.
- `sapXep`: `TEN_A_Z`, `GIA_TANG`, `GIA_GIAM` hoặc `DANH_GIA_CAO`.

Các tham số cũ như `tuKhoa`, `maDanhMuc`, `maThuongHieu`, `maCuaHang`, `trang`, `kichThuocTrang` vẫn giữ nguyên.

## Đánh giá của khách

- `PUT /api/danh-gia/{id}`: chủ đánh giá cập nhật số sao, nhận xét và danh sách điểm nổi bật.
- `DELETE /api/danh-gia/{id}`: chủ đánh giá xóa đánh giá cùng ảnh trên Cloudinary.

Đánh giá đã bị Admin ẩn không thể được khách tự sửa để công khai lại. Admin vẫn dùng các API ẩn/khôi phục hiện có.

## Thông báo nghiệp vụ

Backend lưu thông báo trong `ThongBao` và gửi FCM nếu tài khoản có token thiết bị đang hoạt động:

| Event code | Thời điểm phát sinh |
|---|---|
| `CONTRACT_READY_FOR_HANDOVER` | Staff/Admin hoàn tất gán thiết bị, hợp đồng chuyển sang `CHO_BAN_GIAO` |
| `CONTRACT_RETURN_DUE_SOON` | Hợp đồng `DANG_THUE` còn không quá số giờ cấu hình trước hạn trả |
| `CONTRACT_RETURN_OVERDUE` | Hợp đồng `DANG_THUE` đã quá hạn trả |

Thời hạn được tính theo phụ lục gia hạn `DA_XAC_NHAN` mới nhất, nếu có. Mỗi hợp đồng chỉ nhận một thông báo cho từng event code.

Thiết lập mặc định:

```json
"Rental": {
  "ReturnReminderHours": 24,
  "ReturnReminderScanMinutes": 5
}
```

Các phần thanh toán, VNPAY, ảnh chữ ký, thao tác sao chép ngân hàng và điều hướng màn hình mobile không thay đổi.
