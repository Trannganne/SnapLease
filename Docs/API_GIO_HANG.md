# API giỏ hàng

Tất cả endpoint yêu cầu Bearer token của khách hàng. Giỏ hàng không giữ thiết bị;
tồn kho chỉ được giữ khi khách chuyển sang luồng giữ chỗ. Giá và tiền cọc luôn do
backend tính lại từ dữ liệu dòng máy.

## Danh sách endpoint

| Endpoint | Ý nghĩa |
|---|---|
| `GET /api/gio-hang` | Lấy giỏ hiện tại, chi tiết từng dòng, khả dụng và tổng tiền |
| `GET /api/gio-hang/tam-tinh` | Lấy phần tổng hợp tiền thuê/cọc của toàn giỏ |
| `POST /api/gio-hang/chi-tiet` | Thêm dòng máy vào giỏ; dòng trùng hoàn toàn sẽ cộng số lượng |
| `PUT /api/gio-hang/chi-tiet/{id}` | Sửa số lượng, thời gian hoặc chi nhánh của một dòng |
| `DELETE /api/gio-hang/chi-tiet/{id}` | Xóa một dòng; backend dọn giỏ rỗng nếu không còn tham chiếu |

## Thêm vào giỏ

```http
POST /api/gio-hang/chi-tiet
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "maCuaHang": "CH001",
  "maDongMay": "DONG001",
  "soLuong": 2,
  "ngayBatDau": "2026-10-25T08:00:00",
  "ngayKetThuc": "2026-10-28T18:00:00"
}
```

Thời gian gửi theo giờ địa phương, không thêm `Z` hoặc offset múi giờ. Khoảng thuê
phải ở tương lai, tối đa 90 ngày và số lượng mỗi dòng từ 1 đến 10. Backend kiểm tra
cửa hàng, dòng máy và số lượng còn trống trước khi ghi.

## Sửa một dòng

Body hỗ trợ cập nhật một phần. Trường không gửi hoặc gửi `null` sẽ giữ nguyên.

```json
{
  "maCuaHang": "CH002",
  "soLuong": 1,
  "ngayBatDau": "2026-10-26T08:00:00",
  "ngayKetThuc": "2026-10-29T18:00:00"
}
```

Backend tính lại `donGiaSauGiam`, `tongTienThue`, `tongTienCoc` và kiểm tra tồn kho.

## Response giỏ hàng

`GET /api/gio-hang` trả:

- mã và trạng thái giỏ;
- số dòng, tổng số lượng, tổng tiền thuê, tổng tiền cọc;
- `tatCaConDuHang` cho toàn giỏ;
- từng dòng gồm cửa hàng, dòng máy, ảnh đại diện, thời gian, giá và
  `soLuongConTrong`/`conDuHang`.

Nếu khách chưa có giỏ, API vẫn trả `200 OK` với `trangThai: "TRONG"`, tổng bằng 0
và danh sách `chiTiet` rỗng.
