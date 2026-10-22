# API đăng xuất

```http
POST /api/auth/logout
Authorization: Bearer <access-token>
```

API thu hồi đúng Bearer token đang được sử dụng và trả về `204 No Content`.
Sau khi đăng xuất, token đó bị từ chối ngay cả khi thời hạn một giờ chưa kết thúc.
Các phiên đăng nhập bằng token khác của cùng tài khoản không bị ảnh hưởng.
