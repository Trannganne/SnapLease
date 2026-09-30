# Database Rental Camera — bản chính thức

Thư mục này chứa database cuối dùng chung cho Backend, Web và Mobile.

## File sử dụng

1. `01_schema.sql`: tạo database `RentalCameraDb20` và cấu trúc 22 bảng.
2. `02_sample_data.sql`: nạp dữ liệu mẫu tương thích với cấu trúc trên.

Docker Compose tự chạy hai file theo đúng thứ tự. Thành viên không cần import SQL thủ công.

Không dùng các script của cấu trúc `DonThue` cũ với database này.
