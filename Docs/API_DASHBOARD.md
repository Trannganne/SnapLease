# API Dashboard

Nhóm API dành cho quản trị viên và nhân viên, yêu cầu Bearer token và quyền `Staff`.
Nhân viên chỉ xem được cửa hàng của mình; quản trị viên truyền `maCuaHang` để chọn cửa hàng.

## Bộ lọc chung

- `maCuaHang`: mã cửa hàng (bắt buộc với quản trị viên).
- `tuNgay`, `denNgay`: khoảng ngày dạng ISO 8601. Nếu bỏ trống, hệ thống lấy một tháng gần nhất đến hôm nay.

## Các chỉ số hiện có

- `GET /api/bao-cao/tong-quan`: tổng hợp hợp đồng, doanh thu và thiết bị.
- `GET /api/bao-cao/doanh-thu`: doanh thu theo tháng và loại khoản thu.
- `GET /api/bao-cao/don-thue`: số hợp đồng theo trạng thái.
- `GET /api/bao-cao/tinh-trang-thiet-bi`: số thiết bị theo trạng thái và tình trạng.

## Tiền cọc đang giữ

`GET /api/bao-cao/tien-coc-dang-giu`

Chỉ tính giao dịch `TIEN_COC` ở trạng thái `THANH_CONG`. Khoản `HOAN_COC` ở trạng thái
`DA_HOAN` được trừ khỏi tiền cọc đã thu; hợp đồng có số dư bằng 0 không còn nằm trong danh sách.

Phản hồi gồm `soHopDong`, `tongTienCocDangGiu` và `duLieu` chi tiết từng hợp đồng.

## Hợp đồng trễ hạn

`GET /api/bao-cao/hop-dong-tre-han`

Tham số bổ sung:

- `trang`: trang cần lấy, mặc định 1.
- `kichThuocTrang`: số dòng mỗi trang, mặc định 20, tối đa 100.

Chỉ liệt kê hợp đồng `DANG_THUE` hoặc `CHO_HOAN_TRA` đã quá hạn. Nếu hợp đồng có phụ lục
`DA_XAC_NHAN`, API sử dụng hạn trả mới nhất. Phản hồi có tổng số, phân trang, số giờ và số ngày trễ.
