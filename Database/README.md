# Database Rental Camera — bản chính thức

Thư mục này chứa database cuối dùng chung cho Backend, Web và Mobile.

## File sử dụng

1. `01_schema.sql`: tạo database `RentalCameraDb20` và cấu trúc database hiện hành.
2. `02_sample_data.sql`: nạp dữ liệu mẫu tương thích với cấu trúc trên.
3. `03_update_cloudinary_images.sql`: cập nhật URL Cloudinary cho database đã khởi tạo bằng dữ liệu mẫu cũ.
4. `04_add_home_contract_test_data.sql`: bổ sung dữ liệu kiểm thử contract Home cho database demo đã tồn tại; script có thể chạy lại an toàn.
5. `06_add_electronic_signature.sql`: bổ sung bảng và các cột xác nhận hợp đồng bằng OTP; script có thể chạy lại an toàn.
6. `07_add_vnpay_payment.sql`: bổ sung dữ liệu thanh toán VNPAY; script có thể chạy lại an toàn.
7. `08_add_firebase_notifications.sql`: bổ sung token thiết bị và định tuyến thông báo FCM; script có thể chạy lại an toàn.
8. `09_add_review_details.sql`: bổ sung trạng thái hiển thị, chip điểm nổi bật và ảnh đánh giá; đánh giá mới công khai ngay; script có thể chạy lại an toàn.
9. `10_add_cart_review_test_data.sql`: bổ sung dữ liệu kiểm thử giỏ hàng, tồn kho và đánh giá với ngày động; script có thể chạy lại an toàn.
10. `11_add_large_test_dataset.sql`: bổ sung bộ dữ liệu lớn để kiểm thử lọc, phân trang, dashboard và các trạng thái nghiệp vụ; gồm 8 khách hàng, 24 thiết bị, 14 giỏ hàng, 10 hợp đồng, 18 thanh toán, 6 đánh giá và 24 thông báo; script có thể chạy lại an toàn.

Docker Compose tự chạy schema, dữ liệu mẫu và các migration cần thiết theo đúng thứ tự. Thành viên không cần import SQL thủ công.

Khi database đã tồn tại, Docker Compose tự chạy migration thuê ngay, các migration
từ `06` đến `09`, rồi bổ sung dữ liệu kiểm thử `10` và `11`; không xóa dữ liệu cũ.

Máy đã có database trước khi URL Cloudinary được cập nhật chỉ chạy `03_update_cloudinary_images.sql`; không chạy lại schema hoặc seed.

Máy đã có database demo và cần kiểm thử `rating`, `reviewCount`, `available`, `branchIds` cùng trường hợp ảnh `null` thì chạy thêm `04_add_home_contract_test_data.sql`.

Không dùng các script của cấu trúc `DonThue` cũ với database này.

### 14_add_asset_operations.sql

Bổ sung trạng thái kinh doanh cho dòng máy, phiếu bảo trì, ghi nhận/lịch sử hư hỏng và lịch sử điều chuyển thiết bị giữa các chi nhánh.
