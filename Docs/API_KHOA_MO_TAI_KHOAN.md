# API khóa/mở tài khoản

Các endpoint chỉ dành cho tài khoản có vai trò `ADMIN`.

## Thay đổi trạng thái tài khoản

```http
PUT /api/tai-khoan/{id}/trang-thai
Content-Type: application/json
Authorization: Bearer <access-token>
```

```json
{
  "trangThai": "TAM_KHOA",
  "lyDo": "Tạm khóa theo yêu cầu quản trị"
}
```

`trangThai` nhận `HOAT_DONG` hoặc `TAM_KHOA`. Backend lưu trạng thái cũ,
trạng thái mới, lý do, thời gian và mã tài khoản Admin thực hiện thao tác.

Khi tài khoản bị khóa, Bearer token đang có bị từ chối ngay ở lần gọi API tiếp
theo và các FCM device token đang hoạt động của tài khoản cũng bị vô hiệu hóa.
Admin không thể tự khóa chính mình hoặc khóa Admin hoạt động cuối cùng.

## Xem lịch sử thay đổi

```http
GET /api/tai-khoan/{id}/lich-su-trang-thai
Authorization: Bearer <access-token>
```

Kết quả được sắp xếp từ thao tác mới nhất đến cũ nhất.
