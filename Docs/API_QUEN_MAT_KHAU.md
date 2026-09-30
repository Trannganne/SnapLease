# API quên mật khẩu

Base URL khi chạy Docker trên máy phát triển: `http://localhost:5000`.

## 1. Yêu cầu đặt lại mật khẩu

```http
POST /api/auth/quen-mat-khau
Content-Type: application/json
```

```json
{
  "tenDangNhapHoacEmail": "khachhang01"
}
```

Response luôn dùng thông báo chung để hạn chế dò tài khoản:

```json
{
  "thongBao": "Nếu tài khoản tồn tại, yêu cầu đặt lại mật khẩu đã được tạo.",
  "resetToken": "...",
  "expiresInSeconds": 900
}
```

Trong Docker Development, `resetToken` được trả về để Web/Mobile kiểm thử. Khi triển khai thật phải đặt `PasswordReset__ReturnTokenInResponse=false` và gửi token qua email/SMS do hệ thống tin cậy.

## 2. Đặt mật khẩu mới

```http
POST /api/auth/dat-lai-mat-khau
Content-Type: application/json
```

```json
{
  "resetToken": "TOKEN_NHAN_O_BUOC_1",
  "matKhauMoi": "MatKhau@123"
}
```

Mật khẩu mới phải có 8–128 ký tự, gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.

Thành công trả `204 No Content`. Token có hạn 15 phút và tự mất hiệu lực sau khi mật khẩu được đổi.

## Mã lỗi chính

- `400`: dữ liệu, mật khẩu hoặc token không hợp lệ/hết hạn/đã sử dụng.
- `429`: gọi quá 5 lần trong một phút từ cùng địa chỉ IP.
