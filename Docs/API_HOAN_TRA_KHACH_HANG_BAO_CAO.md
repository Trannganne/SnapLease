# API hoàn trả, khách hàng, báo cáo và hệ thống

Tất cả API dưới đây yêu cầu Bearer token. Nhân viên chỉ xem dữ liệu thuộc chi nhánh của mình; Admin có thể truyền `maCuaHang` để lọc.

## Hoàn trả

- `GET /api/hoan-tra/cho-nhan`: danh sách hợp đồng `CHO_HOAN_TRA`, có phân trang và lọc chi nhánh/ngày dự kiến trả.
- `GET /api/hop-dong/{id}/phi-tra-tre?thoiGianTra=...`: xem trước phí trả trễ. Quy tắc: số ngày trễ làm tròn lên, phí mỗi ngày bằng tổng đơn giá của các serial trong hợp đồng; hạn trả ưu tiên phụ lục đã duyệt mới nhất.
- `POST /api/hop-dong/{id}/phi-tra-tre`: tính và lập/cập nhật phiếu phạt `TRA_TRE` đang chờ xác nhận.
- `POST /api/hop-dong/{id}/phi-hu-hong`: lập phí sửa chữa và phụ kiện thiếu theo từng chi tiết hợp đồng. Body mẫu:

```json
{
  "thietBi": [
    {
      "maChiTietHopDong": "CTHD001",
      "chiPhiSuaChua": 250000,
      "chiPhiPhuKienThieu": 100000,
      "ghiChu": "Trầy ống kính, thiếu nắp"
    }
  ]
}
```

Các API nhận lại thiết bị, ảnh biên bản, hoàn cọc và hoàn tất hợp đồng hiện có được giữ nguyên.

## Gia hạn

`PUT /api/gia-han/{id}/xu-ly` vẫn dùng body `quyetDinh=DUYET|TU_CHOI`. Sau xử lý, hệ thống lưu thông báo và gửi FCM cho tài khoản khách hàng với `eventCode=CONTRACT_EXTENSION_RESULT`.

## Khách hàng

- `GET /api/khach-hang`: danh sách, tìm theo mã/tên/SĐT/email/CCCD, lọc trạng thái tài khoản và tình trạng xác nhận hồ sơ.
- `GET /api/khach-hang/{id}`: hồ sơ, tài khoản, giấy tờ và thống kê hợp đồng.
- `GET /api/khach-hang/{id}/hop-dong`: lịch sử hợp đồng, lọc chi nhánh/trạng thái và phân trang.

Không bổ sung hoặc thay đổi API lịch sử thanh toán trong đợt này.

## Báo cáo

- `GET /api/bao-cao/hieu-suat-dong-may`
- `GET /api/bao-cao/ty-le-su-dung-thiet-bi`
- `GET /api/bao-cao/tien-coc-va-phieu-phat`
- `GET /api/bao-cao/xuat?loai=HIEU_SUAT_DONG_MAY&dinhDang=EXCEL`

`loai` nhận `HIEU_SUAT_DONG_MAY`, `TY_LE_SU_DUNG`, `TIEN_COC_PHAT`; `dinhDang` nhận `EXCEL` hoặc `PDF`. Tất cả hỗ trợ `maCuaHang`, `tuNgay`, `denNgay`.

## Hệ thống

- Thao tác `POST`, `PUT`, `PATCH`, `DELETE` đã xác thực được ghi vào `NhatKyHeThong` sau khi có phản hồi.
- `GET /api/he-thong/nhat-ky`: chỉ Admin, lọc theo tài khoản, hành động, đối tượng, thời gian và phân trang.
- Thông báo hoàn trả dùng `eventCode=CONTRACT_RETURN_RECEIVED`; thông báo gia hạn dùng `CONTRACT_EXTENSION_RESULT`.

## Database

Chạy migration `Database/16_add_operations_audit.sql`. Docker Compose đã được cấu hình tự chạy migration này cho cả database mới và database hiện có.
