# SnapLease — Backend API

Backend dùng chung cho ứng dụng Web và Mobile của hệ thống đặt/thuê máy ảnh SnapLease.

## Công nghệ

- ASP.NET Core 8 Minimal API
- Entity Framework Core 8
- SQL Server 2022
- Docker Compose
- Swagger/OpenAPI
- Bearer token bằng ASP.NET Core Data Protection

## Cấu trúc

```text
Backend_Api/
├── RentalCamera.Api/                 Mã nguồn API
├── Database/
│   ├── 01_schema.sql                 Cấu trúc database chính thức (22 bảng)
│   ├── 02_sample_data.sql            Dữ liệu mẫu
│   └── README.md                      Mô tả database và flow đặt thuê
├── Docs/                              Tài liệu bàn giao/tích hợp
├── compose.yaml                       Chạy API + SQL Server + khởi tạo DB
├── .env.example                       Mẫu biến môi trường
├── .gitignore                         Loại trừ mật khẩu và file build
└── HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md
```

## Chạy bằng Docker

### 1. Yêu cầu

- Git
- Docker Desktop sử dụng Linux containers
- Docker Desktop đang hiển thị `Engine running`

### 2. Tạo cấu hình cá nhân

Mở PowerShell tại thư mục chứa `compose.yaml`:

```powershell
Copy-Item .env.example .env
```

File `.env` chỉ dùng trên máy cá nhân và không được commit lên GitHub.

### 3. Khởi động hệ thống

```powershell
docker compose up -d --build
docker compose ps -a
```

Trạng thái đúng:

```text
rentalcamera-sql       Up (healthy)
rentalcamera-db-init   Exited (0)
rentalcamera-api       Up
```

`db-init` thoát với mã `0` là bình thường: dịch vụ này chỉ tạo cấu trúc và nạp dữ liệu mẫu một lần.

### 4. Kiểm tra

- Health: <http://localhost:5000/api/health>
- Swagger: <http://localhost:5000/swagger>
- OpenAPI JSON: <http://localhost:5000/swagger/v1/swagger.json>

`/api/health` chỉ xác nhận API đã chạy. Gọi thêm `GET /api/danh-muc` hoặc `GET /api/dong-may` để kiểm tra kết nối database.

## Tài khoản mẫu

Đặt mật khẩu cho tài khoản cần dùng:

```powershell
docker compose exec api dotnet RentalCamera.Api.dll set-password khachhang01
docker compose exec api dotnet RentalCamera.Api.dll set-password nhanvien01
docker compose exec api dotnet RentalCamera.Api.dll set-password admin01
```

Mật khẩu phải có 8–128 ký tự, gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt. Sau đó đăng nhập bằng `POST /api/auth/login`.

Sao chép `accessToken`, mở nút **Authorize** trong Swagger và dán token trực tiếp.

## Base URL cho Web và Mobile

| Môi trường | Base URL |
|---|---|
| Web chạy cùng máy | `http://localhost:5000` |
| Android Emulator | `http://10.0.2.2:5000` |
| Điện thoại thật cùng Wi-Fi | `http://<IP_LAN_MAY_CHAY_BACKEND>:5000` |

Web phải dùng origin đã được khai báo trong CORS. Mobile native không chịu chính sách CORS của trình duyệt.

## Chạy lại và cập nhật

Sau khi tắt/bật máy:

```powershell
docker compose up -d
```

Sau khi Backend thay đổi:

```powershell
docker compose up -d --build api
```

Xem log:

```powershell
docker compose logs -f api
```

Chỉ khi cần xóa toàn bộ database Docker và dựng lại từ đầu:

```powershell
docker compose down -v
docker compose up -d --build
```

> `docker compose down -v` xóa toàn bộ dữ liệu đang lưu trong volume SQL Server.

## Quy ước bảo mật

Không commit các nội dung sau:

- `.env`
- `bin/`, `obj/`
- `.keys/`
- Token đăng nhập
- Mật khẩu hoặc connection string chứa mật khẩu thật
- Dữ liệu cá nhân thật của khách hàng

## Làm việc trên Git

- Code Backend nằm trên nhánh `backend`.
- Nhánh `main` do nhóm trưởng quản lý.
- Không merge trực tiếp vào `main` khi chưa được nhóm trưởng kiểm tra.
- Web và Mobile tích hợp theo Swagger và tài liệu trong thư mục `Docs`.

Hướng dẫn chi tiết: [`HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md`](./HUONG_DAN_CHAY_DOCKER_CHO_THANH_VIEN.md).
