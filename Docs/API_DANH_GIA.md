# API đánh giá thiết bị

Tài liệu này mô tả luồng đánh giá thiết bị theo giao diện Figma. Khách hàng chỉ
được đánh giá thiết bị thuộc hợp đồng của mình sau khi hợp đồng đã hoàn thành.

## Quy trình phía Mobile

1. Gọi `GET /api/danh-gia/bieu-mau/{maChiTietHopDong}` để lấy thông tin thiết bị,
   trạng thái đủ điều kiện, giới hạn nội dung và danh sách chip cố định.
2. Gọi `POST /api/danh-gia` để tạo đánh giá gồm số sao, nhận xét và các mã chip.
3. Lấy `maDanhGia` từ response rồi gọi `POST /api/danh-gia/{id}/anh` cho từng ảnh.
   Mỗi đánh giá được tải tối đa 4 ảnh.
4. Đánh giá mới có trạng thái `CHO_DUYET`; chỉ đánh giá `DA_DUYET` xuất hiện trong
   danh sách công khai.

Tất cả endpoint của khách hàng yêu cầu Bearer token có quyền `Customer`.

## Lấy dữ liệu biểu mẫu

```http
GET /api/danh-gia/bieu-mau/CTHD001
Authorization: Bearer <accessToken>
```

Response chứa thông tin hợp đồng, thiết bị, ảnh đại diện, `duocDanhGia`, lý do
nếu không đủ điều kiện, giới hạn 500 ký tự, giới hạn 4 ảnh và danh sách chip.
Mobile phải gửi lại trường `ma` của chip, không gửi nội dung hiển thị.

Các mã chip hiện có:

| Mã | Nội dung |
|---|---|
| `CHAT_LUONG_HINH_ANH_TOT` | Chất lượng hình ảnh tốt |
| `THIET_BI_HOAT_DONG_ON_DINH` | Thiết bị hoạt động ổn định |
| `NGOAI_HINH_CON_MOI` | Ngoại hình còn mới |
| `PIN_SU_DUNG_TOT` | Pin sử dụng tốt |
| `DE_SU_DUNG` | Dễ sử dụng |
| `PHU_KIEN_DAY_DU` | Phụ kiện đầy đủ |

## Tạo đánh giá

```http
POST /api/danh-gia
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "maChiTietHopDong": "CTHD001",
  "soSao": 5,
  "nhanXet": "Máy hoạt động tốt, ảnh đẹp và dễ sử dụng.",
  "diemNoiBat": [
    "CHAT_LUONG_HINH_ANH_TOT",
    "THIET_BI_HOAT_DONG_ON_DINH",
    "DE_SU_DUNG"
  ]
}
```

Kết quả thành công là `201 Created`. Response trả đầy đủ đánh giá, thông tin thiết
bị, chip đã chọn và danh sách ảnh. Mobile dùng `maDanhGia` trong response cho bước
tải ảnh.

## Tải ảnh thực tế

```http
POST /api/danh-gia/{maDanhGia}/anh
Authorization: Bearer <accessToken>
Content-Type: multipart/form-data
```

Form chỉ có một trường file tên `anh`. Chấp nhận JPEG, PNG, WEBP; dung lượng tối đa
lấy theo cấu hình Cloudinary (mặc định 10 MB). Gọi endpoint một lần cho mỗi ảnh.

## Danh sách và kiểm duyệt

| Endpoint | Quyền | Ý nghĩa |
|---|---|---|
| `GET /api/dong-may/{id}/danh-gia?trang=1&kichThuocTrang=20` | Công khai | Chỉ trả đánh giá đã duyệt |
| `GET /api/danh-gia/cua-toi` | Customer | Trả mọi đánh giá của khách và trạng thái kiểm duyệt |
| `PUT /api/danh-gia/{id}/kiem-duyet` | Staff/Admin | Duyệt hoặc từ chối đánh giá thuộc cửa hàng |

Body kiểm duyệt:

```json
{
  "trangThai": "DA_DUYET",
  "ghiChu": null
}
```

`trangThai` nhận `DA_DUYET` hoặc `TU_CHOI`. Ghi chú kiểm duyệt tối đa 500 ký tự và
không được trả trong API danh sách công khai.

## Cấu hình ảnh

Backend dùng chung tài khoản Cloudinary với ảnh biên bản, nhưng lưu ảnh đánh giá ở
folder riêng:

```env
CLOUDINARY_REVIEW_FOLDER=rental-camera/danh-gia
```

File khóa Cloudinary và API secret chỉ đặt trong `.env` của backend, không đưa vào
Mobile hoặc commit lên Git.
