# Database Rental Camera — bản chính thức

Thư mục này chứa database cuối dùng chung cho Backend, Web và Mobile.

## File sử dụng

1. `01_schema.sql`: tạo database `RentalCameraDb20` và cấu trúc 22 bảng.
2. `02_sample_data.sql`: nạp dữ liệu mẫu tương thích với cấu trúc trên.

Docker Compose tự chạy hai file theo đúng thứ tự. Thành viên không cần import SQL thủ công.

## Flow đặt thuê

```text
GioHang
  -> GiuCho (TTL 20 phút)
  -> HopDong (CHO_KY)
  -> DA_KY
  -> CHO_BAN_GIAO
  -> DANG_THUE
  -> CHO_HOAN_TRA
  -> HOAN_THANH
```

- `GioHang` không giữ số lượng thiết bị.
- `GiuCho` và `ChiTietGiuCho` giữ capacity trong thời gian TTL.
- Kiểm tra lịch trống phải trừ hợp đồng đang chiếm lịch và giữ chỗ chưa hết hạn.
- Khi giữ chỗ hết hạn, Backend chuyển trạng thái sang `HET_HAN` để trả capacity.
- Khách đặt theo `DongMay` và số lượng; serial thiết bị được nhân viên gán sau khi hợp đồng đã ký.
- Khi sửa giữ chỗ, lập hợp đồng hoặc duyệt gia hạn, Backend phải kiểm tra lịch lại trong transaction.

Không dùng các script của cấu trúc `DonThue` cũ với database này.
