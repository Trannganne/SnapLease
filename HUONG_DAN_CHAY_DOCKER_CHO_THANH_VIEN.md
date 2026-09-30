# HƯỚNG DẪN CHẠY BACKEND RENTAL CAMERA BẰNG DOCKER

Tài liệu này dành cho thành viên phát triển Web và Mobile. Sau khi thực hiện xong, máy sẽ chạy đồng thời:

- ASP.NET Core API.
- SQL Server.
- Cấu trúc database và dữ liệu mẫu.

Không cần cài SQL Server, không cần mở file SQL và không cần import database thủ công.

## 1. Phần mềm cần cài

1. Git.
2. Docker Desktop.
3. Docker Desktop phải sử dụng Linux containers.

Sau khi cài Docker Desktop, mở ứng dụng và chờ góc dưới bên trái hiển thị:

```text
Engine running
```

Kiểm tra bằng PowerShell:

```powershell
docker info --format '{{.OSType}}'
```

Kết quả đúng:

```text
linux
```

## 2. Lấy mã nguồn

Nếu nhận mã nguồn từ GitHub:

```powershell
git clone <LINK_GITHUB_CUA_NHOM>
cd <TEN_THU_MUC_DA_CLONE>
```

Nếu repository có thư mục `Backend_Api`:

```powershell
cd Backend_Api
```

Nếu nhận thư mục trực tiếp, mở PowerShell tại thư mục đó. Ví dụ:

```powershell
cd D:\Backend_Api
```

Thư mục backend phải có tối thiểu:

```text
Backend_Api
├── compose.yaml
├── .env.example
├── Database
│   ├── 01_schema.sql
│   └── 02_sample_data.sql
└── RentalCamera.Api
    ├── Dockerfile
    └── RentalCamera.Api.csproj
```

## 3. Tạo file cấu hình cá nhân

Chạy:

```powershell
Copy-Item .env.example .env
```

Nếu không có `.env.example`, tạo file `.env` tại cùng vị trí với `compose.yaml`:

```powershell
notepad .env
```

Nội dung:

```env
MSSQL_SA_PASSWORD=RentalCam@2026!
```

Không đưa file `.env` lên GitHub và không gửi mật khẩu môi trường thật vào nhóm chat.

## 4. Kiểm tra cấu hình Docker Compose

Chạy tại thư mục chứa `compose.yaml`:

```powershell
docker compose config
```

Nếu cấu hình hợp lệ, Docker sẽ in ra ba dịch vụ:

```text
sqlserver
db-init
api
```

Nếu nhận lỗi `no configuration file provided`, bạn đang đứng sai thư mục hoặc thiếu file `compose.yaml`.

## 5. Chạy lần đầu

Đảm bảo Docker Desktop đang ở trạng thái `Engine running`, sau đó chạy:

```powershell
docker compose up -d --build
```

Lần đầu Docker phải tải SQL Server và .NET, thời gian có thể từ 10 đến 30 phút tùy tốc độ mạng. Không đóng PowerShell khi đang hiển thị `Pulling` hoặc `Building`.

Sau khi hoàn tất, kiểm tra:

```powershell
docker compose ps -a
```

Trạng thái mong đợi:

```text
rentalcamera-sql       Up (healthy)
rentalcamera-db-init   Exited (0)
rentalcamera-api       Up
```

`db-init` có trạng thái `Exited (0)` là bình thường. Dịch vụ này chỉ tạo database và nhập dữ liệu mẫu một lần rồi kết thúc.

## 6. Kiểm tra backend

Mở trình duyệt:

```text
http://localhost:5000/api/health
```

Kết quả đúng:

```json
{
  "status": "ok"
}
```

Swagger:

```text
http://localhost:5000/swagger
```

## 7. Đặt mật khẩu cho tài khoản mẫu

Các mật khẩu trong file dữ liệu mẫu không dùng để đăng nhập trực tiếp. Cần đặt lại mật khẩu sau khi database được tạo.

Khách hàng:

```powershell
docker compose exec api dotnet RentalCamera.Api.dll set-password khachhang01
```

Nhân viên:

```powershell
docker compose exec api dotnet RentalCamera.Api.dll set-password nhanvien01
```

Quản trị viên:

```powershell
docker compose exec api dotnet RentalCamera.Api.dll set-password admin01
```

Mật khẩu phải có 8–128 ký tự, gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt. Khi nhập mật khẩu, PowerShell không hiển thị ký tự nhưng vẫn đang nhận dữ liệu. Nhập xong nhấn Enter.

## 8. Đăng nhập trên Swagger

Mở endpoint:

```text
POST /api/auth/login
```

Ví dụ:

```json
{
  "tenDangNhap": "khachhang01",
  "matKhau": "<MAT_KHAU_VUA_DAT>"
}
```

Sao chép trường `accessToken` trong response. Bấm nút **Authorize** trên Swagger và dán trực tiếp token. Không cần tự thêm chữ `Bearer`.

## 9. Địa chỉ API dành cho Web và Mobile

### Web chạy trên cùng máy với Docker

```text
http://localhost:5000
```

### Android Emulator chạy trên cùng máy

```text
http://10.0.2.2:5000
```

Không dùng `localhost` trong Android Emulator vì `localhost` lúc đó là chính máy ảo Android.

### Điện thoại thật

Điện thoại và máy chạy backend phải sử dụng cùng một mạng Wi-Fi.

Trên máy chạy backend, xem IPv4:

```powershell
ipconfig
```

Base URL trên điện thoại:

```text
http://<IPV4_CUA_MAY_CHAY_BACKEND>:5000
```

Ví dụ:

```text
http://192.168.1.10:5000
```

Nếu điện thoại không kết nối được, kiểm tra Windows Firewall và cho phép cổng TCP `5000` trong mạng Private.

## 10. Chạy lại sau khi tắt máy

1. Mở Docker Desktop.
2. Chờ `Engine running`.
3. Mở PowerShell tại thư mục backend.
4. Chạy:

```powershell
docker compose up -d
```

Không cần `--build` nếu không thay đổi mã nguồn hoặc Dockerfile.

## 11. Sau khi sửa mã nguồn backend

Build và chạy lại API:

```powershell
docker compose up -d --build api
```

Nếu thay đổi `compose.yaml` hoặc muốn dựng lại toàn bộ dịch vụ:

```powershell
docker compose up -d --build
```

## 12. Dừng hệ thống

Dừng container nhưng giữ database:

```powershell
docker compose down
```

Khởi động lại:

```powershell
docker compose up -d
```

## 13. Tạo lại database từ đầu

Chỉ sử dụng khi dữ liệu hiện tại không cần giữ:

```powershell
docker compose down -v
docker compose up -d --build
```

**Cảnh báo:** `docker compose down -v` xóa volume và toàn bộ database đang lưu trong Docker.

## 14. Xem log khi có lỗi

Trạng thái tất cả container:

```powershell
docker compose ps -a
```

Log API:

```powershell
docker compose logs api
```

Log SQL Server:

```powershell
docker compose logs sqlserver
```

Log khởi tạo database:

```powershell
docker compose logs db-init
```

Theo dõi log API trực tiếp:

```powershell
docker compose logs -f api
```

Nhấn `Ctrl + C` để ngừng xem log; container vẫn tiếp tục chạy.

## 15. Một số lỗi thường gặp

### `no configuration file provided`

Nguyên nhân: PowerShell không đứng trong thư mục chứa `compose.yaml`.

Xử lý:

```powershell
cd D:\Backend_Api
Get-ChildItem -Force
docker compose config
```

### `failed to connect to the docker API`

Nguyên nhân: Docker Desktop chưa chạy.

Xử lý: mở Docker Desktop, chờ `Engine running`, sau đó chạy lại lệnh.

### Dockerfile không tồn tại

Kiểm tra:

```powershell
Get-ChildItem .\RentalCamera.Api\Dockerfile
```

Nếu file bị lưu thành `Dockerfile.txt`:

```powershell
Rename-Item .\RentalCamera.Api\Dockerfile.txt Dockerfile
```

### Cổng 5000 đang được sử dụng

Đóng ứng dụng đang dùng cổng 5000 hoặc đổi dòng ánh xạ cổng API trong `compose.yaml`, ví dụ:

```yaml
ports:
  - "5001:8080"
```

Sau đó sử dụng:

```text
http://localhost:5001
```

### Cổng SQL Server bị trùng

Compose đang dùng cổng máy tính `14330`, không phải `1433`. Nếu `14330` vẫn bị chiếm, đổi thành:

```yaml
ports:
  - "14331:1433"
```

API không cần sửa chuỗi kết nối vì các container vẫn kết nối nội bộ qua `sqlserver:1433`.

### `db-init` báo database tồn tại nhưng thiếu bảng bắt buộc

`db-init` chủ động dừng để tránh chạy lại toàn bộ schema/seed trên database đang có và gây mất hoặc trùng dữ liệu. Trước tiên lấy log:

```powershell
docker compose logs --tail 100 db-init
```

Không tự chạy `docker compose down -v`. Gửi log cho thành viên Backend để xác định database chỉ là bản khởi tạo dở dang hay đang chứa dữ liệu cần giữ. Chỉ dựng lại database khi đã xác nhận không có dữ liệu cần bảo toàn; database đang sử dụng thật phải được sửa bằng migration hoặc script khôi phục riêng.

## 16. Quy ước làm việc nhóm

- Không commit `.env`.
- Không commit thư mục `bin`, `obj` hoặc khóa trong `.keys`.
- Không chạy `down -v` nếu đang có dữ liệu cần giữ.
- Khi database thay đổi, báo cả nhóm và cung cấp script cập nhật riêng.
- Web và Mobile phải lấy tên trường request/response đúng theo tài liệu API, không tự đoán.
- Docker Compose là môi trường local thống nhất; nó không đồng nghĩa với việc backend đã được deploy công khai.

## 17. Chuỗi lệnh ngắn gọn

Lần đầu:

```powershell
Copy-Item .env.example .env
docker compose up -d --build
docker compose ps -a
```

Những lần sau:

```powershell
docker compose up -d
```

Mở Swagger:

```text
http://localhost:5000/swagger
```
