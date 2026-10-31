# PROJECT_CONTEXT.md

# 1. Project Overview

Project: RentCam

Đề tài:
"Xây dựng ứng dụng quản lý và đặt thuê máy ảnh trực tuyến"

Ứng dụng mobile dành cho khách hàng thuê thiết bị máy ảnh.

Mục tiêu chính:
- tìm kiếm và xem thiết bị
- kiểm tra khả dụng
- thêm dòng máy vào giỏ hàng
- tạo yêu cầu thuê
- theo dõi hợp đồng thuê
- thanh toán/cọc
- bàn giao và trả thiết bị
- đánh giá sau khi thuê

Chi tiết coding convention và architecture nằm trong:
`AI_RULES.md`

---

# 2. Main Mobile Navigation

Bottom Navigation gồm:
1. Trang chủ
2. Khám phá
3. Hợp đồng thuê
4. Thông báo
5. Tài khoản

Authentication screens không có Bottom Navigation.
Device Detail không có Bottom Navigation.

---

# 3. Device Concept

Khách hàng thuê theo dòng máy.

Ví dụ:
- Sony A7 IV
- Canon EOS R6 Mark II

Một dòng máy có thể có nhiều thiết bị vật lý với serial khác nhau.

Khách hàng không chọn serial cụ thể trong giỏ hàng.
Serial được xác định ở bước xử lý/bàn giao.

---

# 4. Shopping Cart

Giỏ hàng là một page riêng.

Không dùng bottom sheet cho Cart.

Cart hoạt động theo:
dòng máy + số lượng

---

# 5. Explore

Tab Khám phá dùng để:
- tìm kiếm
- xem danh sách thiết bị
- lọc
- mở Device Detail

Filter là Bottom Sheet.

Các filter đã chốt:
- Giá
- Ngày thuê
- Chi nhánh
- Loại thiết bị
- Thương hiệu

---

# 6. Rental Flow

Tìm kiếm thiết bị
→ Chọn dòng máy
→ Chọn thời gian thuê
→ Chọn chi nhánh
→ Kiểm tra khả dụng
→ Thêm vào giỏ hàng
→ Gửi yêu cầu thuê
→ Hợp đồng thuê
→ Ký / thanh toán cọc khi cần
→ Bàn giao
→ Theo dõi thuê
→ Trả thiết bị
→ Kiểm tra tình trạng
→ Hoàn tất
→ Đánh giá

---

# 7. Contract

Thuật ngữ chính thức trên mobile:
"Hợp đồng thuê"

Không dùng "Đơn thuê" cho tab chính.

Hợp đồng có thể bao gồm:
- khách hàng
- thiết bị
- thời gian thuê
- chi phí
- tiền cọc
- điều khoản
- trạng thái

Chi tiết nghiệp vụ nằm trong tài liệu contract riêng.

---

# 8. Authentication

Các màn hiện tại:
- Đăng nhập
- Đăng ký
- Quên mật khẩu

Không tự thêm:
- Google Login
- Facebook Login
- Apple Login
- OTP
- biometric login

nếu chưa được yêu cầu.

---

# 9. Notifications

Thông báo là một tab riêng.

Thông báo có thể liên quan đến:
- hợp đồng
- thanh toán
- bàn giao
- trả thiết bị
- gia hạn

Chi tiết event phụ thuộc backend/business rules.

---

# 10. Figma

Figma là nguồn chính cho UI.

Nếu UI hoặc interaction không rõ trong Figma:
hỏi user trước khi triển khai.

Không tự thiết kế thêm màn hình hoặc flow chưa được duyệt.

---

# 11. Business Features in Scope

Hệ thống có thể bao gồm:
- hợp đồng thuê
- tiền cọc
- thanh toán
- eKYC / OCR
- chữ ký
- QR bàn giao / trả thiết bị
- hóa đơn
- đánh giá
- gia hạn
- xử lý hư hỏng / trễ hạn

Chi tiết mỗi feature nằm trong tài liệu riêng.

---

# 12. Source Priority

Ưu tiên:
1. Yêu cầu mới nhất của user
2. Figma frame hiện tại
3. Business rules / database / class diagram đã duyệt
4. PROJECT_CONTEXT.md
5. AI_RULES.md

Nếu có mâu thuẫn:
hỏi user trước khi tự quyết định.