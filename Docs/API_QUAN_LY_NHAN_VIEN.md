# API quản lý nhân viên

Các endpoint chỉ dành cho tài khoản có vai trò `ADMIN`.

## Danh sách nhân viên

```http
GET /api/nhan-vien?tuKhoa=&maCuaHang=&trangThai=&trang=1&kichThuocTrang=20
```

- `tuKhoa`: tìm theo họ tên, tên đăng nhập, số điện thoại hoặc email.
- `maCuaHang`: lọc nhân viên thuộc một chi nhánh.
- `trangThai`: `HOAT_DONG` hoặc `NGHI_VIEC`.
- Kích thước trang tối đa là `100`.

## Chi tiết nhân viên

```http
GET /api/nhan-vien/{id}
```

## Tạo nhân viên

```http
POST /api/nhan-vien
Content-Type: application/json
```

```json
{
  "tenDangNhap": "nhanvien03",
  "matKhau": "NhanVien@2026",
  "maCuaHang": "CH001",
  "hoTen": "Nguyễn Văn Minh",
  "diaChi": "Quận 3, TP.HCM",
  "soDienThoai": "0922000003",
  "chucVu": "Nhân viên cửa hàng",
  "email": "minh@rentalcamera.vn"
}
```

Backend tạo đồng thời `TaiKhoan` vai trò `NHAN_VIEN` và hồ sơ `NhanVien`.
Mật khẩu phải tuân thủ chính sách của hệ thống và chỉ được lưu dưới dạng hash.
Cửa hàng phải tồn tại và đang hoạt động.

## Cập nhật nhân viên

```http
PUT /api/nhan-vien/{id}
Content-Type: application/json
```

```json
{
  "tenDangNhap": "nhanvien03",
  "maCuaHang": "CH002",
  "hoTen": "Nguyễn Văn Minh",
  "diaChi": "TP. Thủ Đức",
  "soDienThoai": "0922000003",
  "chucVu": "Nhân viên vận hành",
  "email": "minh@rentalcamera.vn"
}
```

API cho phép cập nhật thông tin đăng nhập, hồ sơ và chuyển phạm vi cửa hàng.
Khóa/mở tài khoản được tách thành nghiệp vụ riêng trong checklist.
