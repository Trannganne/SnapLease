# API cho các luồng Mobile trên Figma

Base URL khi chạy Docker: `http://localhost:5000`.

Tất cả API hợp đồng, thanh toán và gia hạn cần header:

```http
Authorization: Bearer ACCESS_TOKEN
```

## 1. Xác nhận hợp đồng bằng OTP

Đây là ký điện tử mô phỏng phục vụ đồ án, không phải chữ ký số được nhà cung cấp chứng thư số chứng thực.

Lấy thông tin hợp đồng để hiển thị và kiểm tra trước khi ký:

```http
GET /api/hop-dong/{maHopDong}
```

Khi người dùng tích đồng ý điều khoản, tạo OTP ký:

```http
POST /api/hop-dong/{maHopDong}/yeu-cau-ky
Content-Type: application/json
```

```json
{
  "daDongYDieuKhoan": true
}
```

Response trả `maXacNhan`, thời hạn OTP, phiên bản điều khoản và mã băm nội dung hợp đồng. Trong Development, `maOtp` cũng được trả về để kiểm thử; khi triển khai thật phải gửi OTP qua SMS/email.

Sau khi người dùng nhập OTP và bấm `Ký và xác nhận`:

```http
PUT /api/hop-dong/{maHopDong}/ky
Content-Type: application/json
```

```json
{
  "maXacNhan": "XK...",
  "maOtp": "123456",
  "daDongYDieuKhoan": true,
  "tepHopDongUrl": null
}
```

Backend chỉ cho chính khách hàng sở hữu hợp đồng ký, OTP hết hạn sau 5 phút và khóa sau 5 lần nhập sai. Khi thành công, backend lưu bản chụp JSON của nội dung hợp đồng, mã băm SHA-256, phiên bản điều khoản, IP, thiết bị và thời gian xác nhận rồi chuyển hợp đồng sang `DA_KY`.

Tra cứu dấu vết ký, không trả về mã OTP hoặc mã băm OTP:

```http
GET /api/hop-dong/{maHopDong}/lich-su-ky
```

Lấy lại đúng bản nội dung đã được người dùng xác nhận và kiểm tra mã băm:

```http
GET /api/hop-dong/{maHopDong}/noi-dung-da-ky
```

Response có `maBamHopLe=true` khi nội dung lưu trong database vẫn khớp với mã băm lúc ký.

## 2. Yêu cầu gia hạn

Ứng dụng gọi API dự kiến trước để hiển thị số ngày, chi phí và khả năng gia hạn:

```http
GET /api/hop-dong/{maHopDong}/du-kien-gia-han?thoiHanTraMoi=2026-10-10T17:00:00
```

Khi người dùng xác nhận gửi yêu cầu:

```http
POST /api/hop-dong/{maHopDong}/yeu-cau-gia-han
Content-Type: application/json
```

```json
{
  "thoiHanTraMoi": "2026-10-10T17:00:00",
  "lyDoGiaHan": "Cần sử dụng thiết bị thêm cho buổi chụp",
  "ghiChu": null
}
```

Ứng dụng không gửi chi phí. Backend tự kiểm tra lịch thiết bị, tính số ngày và chi phí dự kiến, sau đó tạo yêu cầu ở trạng thái `CHO_XAC_NHAN`.

Nhân viên xem và xử lý yêu cầu bằng:

```http
GET /api/gia-han/cho-duyet
PUT /api/gia-han/{maPhuLuc}/xu-ly
```

```json
{
  "quyetDinh": "DUYET",
  "ghiChu": null
}
```

## 3. Thanh toán

Tạo khoản thanh toán cọc sau khi hợp đồng đã ký:

```http
POST /api/hop-dong/{maHopDong}/thanh-toan-coc
Content-Type: application/json
```

```json
{
  "phuongThuc": "CHUYEN_KHOAN",
  "noiDungChuyenKhoan": null
}
```

`phuongThuc` nhận `TIEN_MAT`, `CHUYEN_KHOAN` hoặc `VI_DIEN_TU`. Nếu không truyền nội dung chuyển khoản, backend tự tạo theo mẫu `COC {maHopDong}`.

Xem danh sách giao dịch của hợp đồng và theo dõi trạng thái:

```http
GET /api/hop-dong/{maHopDong}/thanh-toan
GET /api/thanh-toan/{maThanhToan}
```

Nhân viên xác nhận giao dịch:

```http
POST /api/thanh-toan/{maThanhToan}/xac-nhan
Content-Type: application/json
```

```json
{
  "thanhCong": true,
  "maGiaoDich": "BANK-20261005-001"
}
```

Với chuyển khoản hoặc ví điện tử, `maGiaoDich` là bắt buộc khi xác nhận thành công.

## 4. Quên mật khẩu

Yêu cầu token bằng email hoặc số điện thoại:

```http
POST /api/auth/quen-mat-khau
Content-Type: application/json
```

```json
{
  "emailHoacSoDienThoai": "0900000001"
}
```

Sau đó đặt mật khẩu mới:

```http
POST /api/auth/dat-lai-mat-khau
Content-Type: application/json
```

```json
{
  "resetToken": "TOKEN_NHAN_O_BUOC_TREN",
  "matKhauMoi": "MatKhau@2026"
}
```

Trong môi trường Development, response bước đầu có thể trả `resetToken` để kiểm thử. Khi triển khai thật phải gửi token qua email/SMS và tắt cấu hình trả token trong response.

## Cập nhật database đang tồn tại

Docker Compose tự chạy script cập nhật. Nếu cần chạy thủ công:

```powershell
docker compose run --rm --no-deps --entrypoint /bin/bash db-init -lc '/opt/mssql-tools18/bin/sqlcmd -S sqlserver -U sa -P "$MSSQL_SA_PASSWORD" -C -b -i /database/06_add_electronic_signature.sql'
```
