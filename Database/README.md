# Database Rental Camera — bản chính thức

Thư mục này chứa database cuối dùng chung cho Backend, Web và Mobile.

## File sử dụng

1. `01_schema.sql`: tạo database `RentalCameraDb20` và cấu trúc 22 bảng.
2. `02_sample_data.sql`: nạp dữ liệu mẫu tương thích với cấu trúc trên.
3. `03_update_cloudinary_images.sql`: cập nhật URL Cloudinary cho database đã khởi tạo bằng dữ liệu mẫu cũ.
4. `04_add_home_contract_test_data.sql`: bổ sung dữ liệu kiểm thử contract Home cho database demo đã tồn tại; script có thể chạy lại an toàn.

Docker Compose tự chạy hai file theo đúng thứ tự. Thành viên không cần import SQL thủ công.

Máy đã có database trước khi URL Cloudinary được cập nhật chỉ chạy `03_update_cloudinary_images.sql`; không chạy lại schema hoặc seed.

Máy đã có database demo và cần kiểm thử `rating`, `reviewCount`, `available`, `branchIds` cùng trường hợp ảnh `null` thì chạy thêm `04_add_home_contract_test_data.sql`.

Không dùng các script của cấu trúc `DonThue` cũ với database này.
