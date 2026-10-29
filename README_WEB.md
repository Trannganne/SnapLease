# SnapLease — Hướng dẫn cài đặt và chạy Web Admin

> Dành cho thành viên nhóm SnapLease sử dụng **Windows + PowerShell + VS Code**. Dự án gồm **Web Admin ASP.NET Core MVC (.NET 8)**, **Backend API ASP.NET Core** và **SQL Server trong Docker**.
>
> Repository: https://github.com/Trannganne/SnapLease

## 1. Chuẩn bị

Cài đặt Git, **.NET SDK 8**, Visual Studio Code (khuyến nghị C# Dev Kit) và Docker Desktop ở chế độ **Linux containers**. SSMS chỉ cần nếu muốn xem dữ liệu trực tiếp.

Kiểm tra bằng PowerShell:

```powershell
git --version
dotnet --version
docker --version
docker compose version
```

Mở Docker Desktop và đợi Docker Engine hoạt động.

## 2. Chuẩn bị Backend

**Nếu chưa tải Backend:**

```powershell
New-Item -ItemType Directory -Force D:\SnapLease
cd D:\SnapLease
git clone --branch backend --single-branch https://github.com/Trannganne/SnapLease.git SnapLease_Backend
```

**Nếu đã tải Backend:**

```powershell
cd D:\SnapLease\SnapLease_Backend
git status
git switch backend
git pull --ff-only origin backend
```

Nếu Git báo có thay đổi cục bộ, hãy kiểm tra và sao lưu trước; **không tự ý dùng `git reset --hard` hay `git clean -fd`**.

### Cấu hình mật khẩu SQL

Trong thư mục Backend, nếu có `.env.example`:

```powershell
cd D:\SnapLease\SnapLease_Backend
Copy-Item .env.example .env
notepad .env
```

Nếu `.env` đã tồn tại thì chỉ mở để kiểm tra, không ghi đè. Đặt `MSSQL_SA_PASSWORD` thành mật khẩu SQL Server đủ mạnh và giữ riêng tư. **Không commit `.env`**.

> Nếu SQL Server đã có dữ liệu trong Docker volume, đổi mật khẩu trong `.env` không tự đổi mật khẩu `sa` của SQL Server đang tồn tại.

## 3. Chạy SQL Server và Backend API

Mở **Terminal 1**:

```powershell
cd D:\SnapLease\SnapLease_Backend
docker compose up -d --build
docker compose ps -a
```

Theo cấu trúc Backend được mô tả trong tài liệu nhóm, các dịch vụ dự kiến gồm:

| Dịch vụ | Trạng thái mong đợi |
|---|---|
| `rentalcamera-sql` | `Up (healthy)` |
| `rentalcamera-db-init` | `Exited (0)` sau khi khởi tạo thành công |
| `rentalcamera-api` | `Up` |

Kiểm tra trên trình duyệt:

- Swagger API: http://localhost:5000/swagger
- Health API (nếu có): http://localhost:5000/api/health

Nếu lỗi, xem tên service thực tế bằng `docker compose config --services`, sau đó xem log (ví dụ với tên service trong tài liệu gốc):

```powershell
docker compose logs --tail=80 sqlserver
docker compose logs --tail=80 db-init
docker compose logs --tail=80 api
```

**Không chạy `docker compose down -v`** khi còn dữ liệu cần giữ vì lệnh có thể xóa volume database.

## 4. Chuẩn bị Web Admin

Có hai cách, **chọn một**:

**Cách A — Chạy code Web đã có sẵn/đã giải nén:** Mở thư mục `D:\SnapLease\SnapLease_MVC` trong VS Code. Đây là cách phù hợp nếu bạn đang dùng bản ZIP giao diện SnapLease đã chỉnh sửa.

**Cách B — Clone nhánh Web (chỉ khi nhánh đã tồn tại trên GitHub):**

```powershell
cd D:\SnapLease
git clone --branch Web --single-branch https://github.com/Trannganne/SnapLease.git SnapLease_Web
```

Tìm đúng thư mục chứa file `RentalCamera.csproj`. Tùy cấu trúc repository, file có thể nằm ở gốc dự án hoặc trong `WebAdmin/`. **Các lệnh .NET sau đây phải chạy tại thư mục chứa `.csproj`.**

## 5. Kết nối Web với SQL Server và API

Web cần cấu hình các khóa sau trong `appsettings.json` hoặc `appsettings.Development.json` (chỉ bổ sung mục cần thiết, **không ghi đè toàn bộ cấu hình hiện có**):

```json
{
  "ConnectionStrings": {
    "RentalCameraConnection": "Server=localhost,14330;Database=RentalCameraDb20;User Id=sa;Password=MAT_KHAU_SQL_CUA_BAN;Encrypt=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
  },
  "ApiSettings": {
    "BaseUrl": "http://localhost:5000/"
  }
}
```

**Khuyến nghị:** Không lưu mật khẩu thật trong file được đưa lên Git. Đặt biến môi trường tại **Terminal 2** trước khi chạy Web:

```powershell
$env:ConnectionStrings__RentalCameraConnection = 'Server=localhost,14330;Database=RentalCameraDb20;User Id=sa;Password=MAT_KHAU_SQL_CUA_BAN;Encrypt=True;TrustServerCertificate=True;MultipleActiveResultSets=true'
$env:ApiSettings__BaseUrl = 'http://localhost:5000/'
```

Thay `MAT_KHAU_SQL_CUA_BAN` bằng mật khẩu SQL đang hoạt động. Cổng `14330` là cổng SQL từ Docker theo cấu hình được nêu trong tài liệu nhóm; nếu `compose.yaml` của bạn khác, phải dùng cổng thực tế.

## 6. Chạy Web Admin trên cổng 5001

Mở **Terminal 2** tại thư mục chứa `RentalCamera.csproj`:

```powershell
cd D:\SnapLease\SnapLease_MVC
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet restore
dotnet run -p:UseAppHost=false --urls "http://localhost:5001"
```

Nếu code Web nằm trong thư mục khác, hãy thay lệnh `cd` cho phù hợp.

Truy cập **http://localhost:5001**. Giữ Terminal mở để Web tiếp tục chạy; nhấn `Ctrl+C` để dừng.

**Cách thay thế nếu `dotnet run` gặp lỗi apphost:**

```powershell
dotnet build -p:UseAppHost=false
dotnet bin\Debug\net8.0\RentalCamera.dll --urls "http://localhost:5001"
```

Lệnh chạy DLL giả định assembly tên `RentalCamera`; nếu khác, xem tên DLL thực tế trong `bin\Debug\net8.0`.

## 7. Mỗi lần mở lại dự án

**Terminal 1 — Backend:**

```powershell
cd D:\SnapLease\SnapLease_Backend
docker compose up -d
docker compose ps -a
```

**Terminal 2 — Web:**

```powershell
cd D:\SnapLease\SnapLease_MVC
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet run -p:UseAppHost=false --urls "http://localhost:5001"
```

Nếu dùng biến môi trường chứa mật khẩu, **phải đặt lại trong Terminal 2 mới** trước lệnh `dotnet run`.

## 8. Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `HTTP ERROR 500` | Xem exception trong Terminal chạy Web; bật môi trường `Development` chỉ khi chạy cục bộ. Kiểm tra kết nối SQL, dữ liệu và API. |
| `Login failed for user 'sa'` | Kiểm tra mật khẩu thực tế, cổng `14330` và Docker volume SQL cũ. |
| `Invalid object name` / `Invalid column name` | Kiểm tra DB init và tính tương thích giữa schema SQL với Web. |
| `Address already in use` ở cổng `5001` | Dừng Web cũ bằng `Ctrl+C`; dùng `netstat -ano | findstr :5001` để xác định tiến trình. |
| `RentalCamera.exe Access denied` | Dừng Web đang chạy và dùng `-p:UseAppHost=false`. |
| Không vào được Swagger | Kiểm tra `docker compose ps -a`, log API và cổng `5000`. |
| CSS cũ hoặc vỡ giao diện | Nhấn `Ctrl+Shift+R`; kiểm tra Network → CSS có file `404` hay không. |
| Razor báo `CS0103: media/max/width` hoặc `CS1003` | Trong file `.cshtml`, nếu có CSS inline `@media`, đổi thành `@@media` hoặc chuyển CSS sang file `.css`. |
| Lỗi khi build | Đọc **lỗi đầu tiên** trong Terminal, sửa rồi chạy `dotnet build -p:UseAppHost=false` để kiểm tra lại. |

## 9. Làm việc với nhánh `Web` (dành cho thành viên dùng Git)

Chỉ thực hiện khi repository đã có nhánh `Web` và bạn có quyền ghi. Không thực hiện các bước Git này nếu chỉ muốn chạy ZIP tải về.

```powershell
cd D:\SnapLease\SnapLease_Web
git switch Web
git pull --ff-only origin Web
# Chỉnh sửa code, chạy thử
git status --short
git add WebAdmin
git diff --cached --name-status
git commit -m "fix(web): improve admin interface"
git push origin Web
```

Nếu dự án nằm ngay gốc nhánh, hãy thay `git add WebAdmin` bằng cách chọn đúng file cần commit. Không đưa `.env`, mật khẩu, `bin/`, `obj/`, log hay file cấu hình cá nhân lên Git.

Nếu nhiều người cùng làm, nên tạo nhánh tính năng từ `Web` và mở Pull Request vào `Web`. **Không `git push --force`** và không tự merge nhánh `backend`/`mobile` vào `Web` chỉ để chạy thử API.

