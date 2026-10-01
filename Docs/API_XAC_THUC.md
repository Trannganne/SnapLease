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
