# API tài sản và chi nhánh

Tất cả thời gian do API trả về sử dụng UTC. Các API ghi dữ liệu yêu cầu Bearer token.

## Dòng máy

- `GET /api/dong-may?trangThai=HOAT_DONG|NGUNG_KINH_DOANH|TAT_CA`
  - Không truyền `trangThai`: chỉ trả dòng máy đang hoạt động.
- `PUT /api/dong-may/{id}/trang-thai` — quyền `Admin`.

```json
{ "trangThai": "NGUNG_KINH_DOANH" }
```

Dòng máy ngừng kinh doanh được giữ nguyên để bảo toàn lịch sử, nhưng không thể thêm mới vào giỏ hàng hoặc giữ chỗ.

## Quản lý chi nhánh

- `GET /api/cua-hang/quan-ly?trangThai=HOAT_DONG|TAM_KHOA` — quyền `Admin`.
- `GET /api/cua-hang/{id}` — quyền `Staff`, nhân viên chỉ xem chi nhánh của mình.
- `POST /api/cua-hang` — quyền `Admin`.
- `PUT /api/cua-hang/{id}` — quyền `Admin`.
- `PUT /api/cua-hang/{id}/trang-thai` — quyền `Admin`.

Không thể khóa chi nhánh khi còn nhân viên hoạt động, thiết bị đang giữ/đang thuê hoặc hợp đồng chưa kết thúc.

## Phiếu bảo trì

- `GET /api/bao-tri?maCuaHang=&maThietBi=&trangThai=`
- `GET /api/bao-tri/{id}`
- `POST /api/bao-tri`
- `PUT /api/bao-tri/{id}`
- `PUT /api/bao-tri/{id}/hoan-tat`

Trạng thái phiếu: `MOI_TAO`, `DANG_XU_LY`, `HOAN_TAT`, `HUY`.
Khi tạo phiếu, thiết bị chuyển sang `BAO_TRI`. Khi hoàn tất, người xử lý phải chọn trạng thái thiết bị là `SAN_SANG`, `HONG` hoặc `NGUNG_KINH_DOANH`.

## Hư hỏng thiết bị

- `GET /api/thiet-bi/{id}/hu-hong`
- `POST /api/thiet-bi/{id}/hu-hong`
- `PUT /api/hu-hong/{id}`

Mức độ: `NHE`, `TRUNG_BINH`, `NANG`. Trạng thái xử lý: `CHUA_SUA`, `DANG_SUA`, `DA_SUA`, `KHONG_SUA`.
Mỗi lần cập nhật trạng thái hoặc chi phí đều được lưu trong `LichSuCapNhatHuHong`.

## Chuyển kho nội bộ

- `POST /api/thiet-bi/{id}/dieu-chuyen`
- `GET /api/thiet-bi/{id}/lich-su-dieu-chuyen`

```json
{
  "maCuaHangMoi": "CH002",
  "lyDo": "Cân đối tồn kho"
}
```

Không thể điều chuyển thiết bị đang giữ, đang thuê hoặc còn thuộc hợp đồng chưa kết thúc. Nhân viên chỉ được chuyển thiết bị từ chi nhánh của mình; Admin không bị giới hạn chi nhánh.

## Database

Migration: `Database/14_add_asset_operations.sql`. Script có thể chạy lại an toàn và đã được thêm vào `compose.yaml`.
