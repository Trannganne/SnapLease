# API xác thực

Base URL khi chạy Docker trên máy phát triển: `http://localhost:5000`.

## 1. Đăng ký khách hàng

```http
POST /api/auth/register
Content-Type: application/json
```

```json
{
  "tenDangNhap": "khachhang03",
  "matKhau": "MatKhau@123",
  "soDienThoai": "0900000003",
  "email": "khachhang03@example.com"
}
```

Đăng ký không nhận `hoTen`. Họ tên được khách hàng cung cấp ở bước gửi giấy tờ xác minh.

## 2. Đăng nhập

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "tenDangNhap": "khachhang03",
  "matKhau": "MatKhau@123"
}
```

Đăng nhập chỉ dùng tên đăng nhập và mật khẩu. Không dùng email hoặc số điện thoại để đăng nhập.

## 2.1. Đăng nhập Google

Flutter đăng nhập Google qua Firebase Authentication, lấy Firebase ID token rồi gọi:

```http
POST /api/auth/google
Content-Type: application/json
```

Tài khoản đã có email trùng với email Google:

```json
{
  "idToken": "<firebase-id-token>",
  "soDienThoai": null
}
```

Nếu API trả `PHONE_REQUIRED_FOR_GOOGLE_SIGNUP`, đây là người dùng Google mới. Flutter hỏi số điện thoại rồi gọi lại:

```json
{
  "idToken": "<firebase-id-token>",
  "soDienThoai": "0900000003"
}
```

Backend chỉ chấp nhận token còn hợp lệ, có `email_verified=true` và được đăng nhập bằng nhà cung cấp `google.com`.
Backend không lưu Google token và không nhận Firebase Admin credential từ mobile. File service-account chỉ đặt riêng trên máy chạy backend.

Để bật tính năng, cấu hình `GOOGLE_LOGIN_ENABLED=true`, `GOOGLE_LOGIN_LIVE_API_APPROVED=true`,
`FIREBASE_PROJECT_ID` và `FIREBASE_ADMIN_CREDENTIALS_FILE`. Firebase Console cũng phải bật nhà cung cấp Google trong Authentication.

## 3. Quên mật khẩu

```http
POST /api/auth/quen-mat-khau
Content-Type: application/json
```

Có thể gửi email:

```json
{
  "emailHoacSoDienThoai": "khachhang03@example.com"
}
```

Hoặc số điện thoại:

```json
{
  "emailHoacSoDienThoai": "0900000003"
}
```

## 4. Gửi giấy tờ và cập nhật họ tên

```http
POST /api/giay-to
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "hoTen": "Nguyễn Văn A",
  "loaiGiayTo": "CCCD",
  "soGiayTo": "012345678901",
  "matTruocUrl": "https://example.com/cccd-front.jpg",
  "matSauUrl": "https://example.com/cccd-back.jpg"
}
```

Khi yêu cầu hợp lệ, API cập nhật `KhachThue.HoTen` và tạo giấy tờ ở trạng thái `CHO_XAC_MINH`.
