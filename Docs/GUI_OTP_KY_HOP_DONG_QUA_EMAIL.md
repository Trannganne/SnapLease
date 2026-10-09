# Gửi OTP ký hợp đồng qua email

Backend lấy địa chỉ nhận từ trường `KhachThue.Email`. Không truyền email người nhận từ Mobile để tránh gửi OTP sang địa chỉ khác với hồ sơ khách hàng.

## Cấu hình Gmail SMTP

1. Bật xác minh 2 bước cho tài khoản Google dùng để gửi email.
2. Tạo **App Password** cho ứng dụng. Không dùng mật khẩu đăng nhập Gmail thông thường.
3. Mở file `.env` tại thư mục chứa `compose.yaml` và điền:

```env
EMAIL_ENABLED=true
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_SSL=true
EMAIL_USERNAME=dia-chi-gmail-dung-de-gui@gmail.com
EMAIL_PASSWORD=mat-khau-ung-dung-16-ky-tu
EMAIL_FROM_ADDRESS=dia-chi-gmail-dung-de-gui@gmail.com
EMAIL_FROM_NAME=Rental Camera
ELECTRONIC_SIGNATURE_RETURN_OTP_IN_RESPONSE=false
```

Không commit file `.env` hoặc App Password lên GitHub.

## Chạy lại API

```powershell
docker compose up -d --build api
docker compose logs -f api
```

## Luồng kiểm thử

1. Tài khoản khách hàng phải có email trong `KhachThue.Email`.
2. Đăng nhập bằng tài khoản khách hàng và lấy access token.
3. Gọi `POST /api/hop-dong/{id}/yeu-cau-ky` với nội dung:

```json
{
  "daDongYDieuKhoan": true
}
```

4. Response thành công có `kenhGui` bằng `EMAIL` và `emailNhan` đã được che một phần.
5. Nhập `maXacNhan` cùng OTP nhận trong email vào `PUT /api/hop-dong/{id}/ky`.

Nếu SMTP gửi thất bại, API trả HTTP 503 và hủy yêu cầu ký vừa tạo. OTP không được trả trong response khi email đã gửi thành công.

## Chế độ kiểm thử không có SMTP

Chỉ khi cần kiểm thử cục bộ, đặt:

```env
EMAIL_ENABLED=false
ELECTRONIC_SIGNATURE_RETURN_OTP_IN_RESPONSE=true
```

Khi đó OTP được trả trong response với `kenhGui` bằng `RESPONSE_KIEM_THU`. Không bật chế độ này trên môi trường thật.
