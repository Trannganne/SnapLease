# API quản lý giữ chỗ và hợp đồng

Nhóm API này dành cho `NHAN_VIEN` và `ADMIN`. Nhân viên chỉ được xem hoặc xử lý dữ liệu thuộc chi nhánh của mình; Admin có thể lọc theo `maCuaHang` để xem một chi nhánh hoặc bỏ trống để xem toàn hệ thống.

## Giữ chỗ

### `GET /api/giu-cho/quan-ly`

Tham số tùy chọn:

- `maCuaHang`: chỉ Admin được chọn chi nhánh khác.
- `trangThai`: `DANG_GIU`, `HET_HAN`, `DA_CHUYEN_HOP_DONG`, `DA_HUY`.
- `tuNgay`, `denNgay`: lọc theo thời điểm tạo.
- `tuKhoa`: tìm theo mã giữ chỗ hoặc mã khách thuê.
- `trang`: mặc định `1`.
- `kichThuocTrang`: mặc định `20`, tối đa `100`.

Trước khi trả danh sách, API đồng bộ các giữ chỗ `DANG_GIU` đã quá `HetHanLuc` thành `HET_HAN`.

### `GET /api/giu-cho/quan-ly/{id}`

Trả thông tin giữ chỗ, khách hàng, chi nhánh, dòng máy, thời gian thuê và hợp đồng đã tạo từ giữ chỗ (nếu có).

## Hợp đồng

### `GET /api/hop-dong/quan-ly`

Tham số tùy chọn:

- `maCuaHang`: lọc chi nhánh theo phạm vi quyền.
- `trangThai`: `CHO_KY`, `DA_KY`, `CHO_BAN_GIAO`, `DANG_THUE`, `CHO_HOAN_TRA`, `HOAN_THANH`, `DA_HUY`.
- `maHopDong`: tìm gần đúng theo mã hợp đồng.
- `tuNgay`, `denNgay`: lọc theo ngày tạo hợp đồng.
- `trang`, `kichThuocTrang`: phân trang, tối đa 100 bản ghi/trang.

### `POST /api/hop-dong/{id}/huy?lyDo=...`

- Khách hàng chỉ được tự hủy hợp đồng `CHO_KY` của chính mình.
- Staff/Admin được hủy hợp đồng thuộc phạm vi chi nhánh khi trạng thái là `CHO_KY`, `DA_KY` hoặc `CHO_BAN_GIAO`.
- Không cho hủy nếu đã có thanh toán thành công hoặc đang xử lý.
- Mỗi lần hủy đều ghi lịch sử trạng thái và người thực hiện.

### `GET /api/hop-dong/{id}/lich-su-trang-thai`

Trả trạng thái cũ/mới, thời gian, tài khoản, vai trò và lý do. Khách hàng chỉ xem hợp đồng của mình; nhân viên chỉ xem hợp đồng cùng chi nhánh; Admin xem được toàn bộ.

## Migration

Chạy `Database/15_add_contract_status_history.sql`. Script có thể chạy lặp lại và tự tạo bản ghi trạng thái ban đầu cho hợp đồng cũ chưa có lịch sử.
