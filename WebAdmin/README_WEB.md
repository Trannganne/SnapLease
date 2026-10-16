# SNAPLEASE — HƯỚNG DẪN CHẠY WEB ADMIN VÀ LÀM VIỆC VỚI NHÁNH `Web`

> Tài liệu dành cho thành viên nhóm phát triển SnapLease. Hệ thống gồm **Web Admin ASP.NET Core MVC (.NET 8)**, **Backend API ASP.NET Core** và **SQL Server chạy Docker**.
>
> Repository: https://github.com/Trannganne/SnapLease
>
> **Lưu ý:** Hướng dẫn dựa trên cấu trúc đã sử dụng trong nhóm: Backend ở nhánh `backend`, Web đang ở thư mục máy cá nhân `D:\SnapLease\SnapLease_MVC`. Nhánh `Web` có thể chưa được tạo. Các bước push cần được thực hiện trên máy có quyền ghi repository.

## 1. Chuẩn bị môi trường

Cài đặt:

- Git
- Visual Studio Code (khuyên dùng C# Dev Kit)
- **.NET SDK 8** (không chỉ .NET Runtime)
- Docker Desktop (chạy **Linux containers**)
- SQL Server Management Studio (SSMS) nếu cần xem dữ liệu, không bắt buộc

Mở PowerShell để kiểm tra:

```powershell
git --version
dotnet --version
docker --version
docker compose version
```

Mở Docker Desktop và đợi Docker Engine chạy trước khi sử dụng `docker compose`.

## 2. Tải Backend về máy

Nếu chưa có mã nguồn Backend:

```powershell
mkdir D:\SnapLease -Force
cd D:\SnapLease
git clone --branch backend --single-branch https://github.com/Trannganne/SnapLease.git SnapLease_Backend
```

Nếu đã có `D:\SnapLease\SnapLease_Backend`:

```powershell
cd D:\SnapLease\SnapLease_Backend
git status
git switch backend
git pull --ff-only origin backend
```

**Không `git reset --hard` hoặc `git clean -fd` khi chưa sao lưu thay đổi của bản thân.** Nếu `git pull` báo có thay đổi cục bộ, dừng lại và hỏi người phụ trách trước khi tiếp tục.

## 3. Tạo file `.env` cho Backend

Trong thư mục `D:\SnapLease\SnapLease_Backend`, sao chép `.env.example` thành `.env`:

```powershell
cd D:\SnapLease\SnapLease_Backend
Copy-Item .env.example .env
notepad .env
```

Tìm dòng:

```dotenv
MSSQL_SA_PASSWORD=
```

Thay bằng mật khẩu SQL Server **mạnh**, ví dụ định dạng `MatKhauRieng@2026!`. Mỗi thành viên nên đặt mật khẩu riêng, lưu nội bộ và không commit `.env`.

Các tích hợp SMTP, VNPAY, Cloudinary có thể để tắt/trống khi chỉ kiểm thử các chức năng cơ bản. Những chức năng phụ thuộc dịch vụ đó sẽ không hoạt động đầy đủ cho đến khi được cấu hình.

**Quan trọng:** Nếu Docker volume SQL Server đã có dữ liệu, thay đổi `.env` **không đổi** mật khẩu `sa` đã lưu trong database. Phải sử dụng mật khẩu cũ hoặc đổi mật khẩu theo quy trình SQL Server.

## 4. Khởi động SQL Server và Backend API

```powershell
cd D:\SnapLease\SnapLease_Backend
docker compose up -d --build
docker compose ps -a
```

Trạng thái mong đợi:

| Container | Trạng thái |
|---|---|
| `rentalcamera-sql` | `Up (healthy)` |
| `rentalcamera-db-init` | `Exited (0)` — chạy xong nhiệm vụ khởi tạo/cập nhật |
| `rentalcamera-api` | `Up` |

Kiểm tra:

- Swagger: http://localhost:5000/swagger
- Health (nếu phiên bản Backend có endpoint): http://localhost:5000/api/health

Nếu có lỗi:

```powershell
docker compose logs --tail=80 sqlserver
docker compose logs --tail=80 db-init
docker compose logs --tail=80 api
```

**Không chạy `docker compose down -v` trên môi trường có dữ liệu cần giữ.** Tùy cấu hình, lệnh này có thể xóa volume chứa database và dữ liệu ứng dụng.

## 5. Tải mã nguồn Web Admin

Sau khi nhánh `Web` đã được người phụ trách tạo và push:

```powershell
cd D:\SnapLease
git clone --branch Web --single-branch https://github.com/Trannganne/SnapLease.git SnapLease_Web
```

Cấu trúc đề xuất trong repository nhánh `Web`:

```text
SnapLease_Web/
├── WebAdmin/
│   ├── RentalCamera.csproj
│   ├── Program.cs
│   ├── Controllers/
│   ├── Models/
│   ├── Views/
│   └── wwwroot/
├── README_WEB.md
└── .gitignore
```

Nếu nhóm quyết định giữ dự án MVC **ngay tại thư mục gốc** của nhánh `Web` thay vì `WebAdmin/`, hãy chạy các lệnh ở mục 6 tại thư mục chứa `RentalCamera.csproj`. Không tạo thêm một cấp `WebAdmin/` nếu mã nguồn đã nằm đúng vị trí.

## 6. Cấu hình Web Admin kết nối SQL Server và API

Mở thư mục chứa `RentalCamera.csproj` trong VS Code. Trong `appsettings.json` hoặc `appsettings.Development.json`, cấu hình phù hợp:

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

Đây là **ví dụ phần cấu hình**, không được thay toàn bộ file nếu file còn các mục khác. Đổi `MAT_KHAU_SQL_CUA_BAN` thành mật khẩu đúng với SQL Server hiện có.

**Khuyến nghị bảo mật:** Không commit mật khẩu thật vào `appsettings.json`. Để dùng biến môi trường trong PowerShell khi chạy Web:

```powershell
$env:ConnectionStrings__RentalCameraConnection = 'Server=localhost,14330;Database=RentalCameraDb20;User Id=sa;Password=MAT_KHAU_SQL_CUA_BAN;Encrypt=True;TrustServerCertificate=True;MultipleActiveResultSets=true'
$env:ApiSettings__BaseUrl = 'http://localhost:5000/'
```

Biến môi trường ASP.NET Core có thể ghi đè giá trị trong `appsettings.json`. Chỉ đặt chúng trong Terminal đang chạy Web, không đưa mật khẩu vào GitHub hoặc ảnh chụp màn hình.

## 7. Chạy Web Admin trên cổng 5001

Trong thư mục chứa `RentalCamera.csproj`:

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet restore
dotnet build -p:UseAppHost=false
dotnet bin\Debug\net8.0\RentalCamera.dll --urls "http://localhost:5001"
```

Mở http://localhost:5001. Giữ Terminal chạy; nhấn `Ctrl+C` để dừng.

> Nếu tên assembly hoặc đường dẫn khác, kiểm tra `<AssemblyName>` trong `.csproj` và file DLL thực tế trong `bin\Debug\net8.0`.

## 8. Sửa lỗi thường gặp

| Lỗi | Cách kiểm tra |
|---|---|
| `HTTP ERROR 500` | Chạy với `ASPNETCORE_ENVIRONMENT=Development`, đọc dòng ngoại lệ đầu tiên trên trang/Terminal |
| `Login failed for user 'sa'` | Đối chiếu mật khẩu trong Web với SQL Server đang chạy, cổng `14330`; kiểm tra `.env` và volume cũ |
| `rentalcamera-sql unhealthy` | `docker compose logs sqlserver` và `docker inspect rentalcamera-sql --format '{{json .State.Health}}'` |
| `Invalid object name` / `Invalid column name` | Kiểm tra `db-init` hoàn thành và schema đúng với mã nguồn Web |
| Cổng `5001` đang được dùng | Dừng phiên Web cũ bằng `Ctrl+C` hoặc kiểm tra tiến trình đang chiếm cổng |
| `RentalCamera.exe Access denied` khi build | Dừng tiến trình Web cũ; dùng `dotnet build -p:UseAppHost=false` và chạy DLL |
| Web mở được nhưng API lỗi | Kiểm tra `http://localhost:5000/swagger`, log API và `ApiSettings:BaseUrl` |

## 9. Tạo nhánh `Web` an toàn — dành cho người phụ trách Web

**Mục tiêu:** Không chỉnh sửa trực tiếp nhánh `backend` hoặc `mobile`, không vô tình đưa code Backend/Mobile vào commit Web.

### 9.1. Sao lưu dự án Web hiện tại

Giữ nguyên `D:\SnapLease\SnapLease_MVC` làm bản dự phòng. Không thao tác `git init` hoặc `git push` vội trong thư mục này nếu chưa kiểm tra repository.

### 9.2. Clone repository ở thư mục riêng

```powershell
cd D:\SnapLease
git clone https://github.com/Trannganne/SnapLease.git SnapLease_Web
git -C D:\SnapLease\SnapLease_Web fetch origin
git -C D:\SnapLease\SnapLease_Web branch -a
```

Nếu nhánh `Web` chưa tồn tại, tạo nhánh từ `main`:

```powershell
cd D:\SnapLease\SnapLease_Web
git switch main
git pull --ff-only origin main
git switch -c Web
```

Nếu `Web` đã tồn tại trên GitHub:

```powershell
cd D:\SnapLease\SnapLease_Web
git switch --track origin/Web
```

> Tên nhánh phân biệt chữ hoa/chữ thường: `Web` khác `web`. Cả nhóm nên thống nhất đúng một tên.

### 9.3. Chép mã nguồn Web vào thư mục riêng

Khuyến nghị đặt dự án Web trong `SnapLease_Web\WebAdmin\` để tách biệt code các thành phần khi sau này merge về `main`.

Trong PowerShell:

```powershell
cd D:\SnapLease\SnapLease_Web
New-Item -ItemType Directory -Force WebAdmin
```

**Chép thủ công** từ `D:\SnapLease\SnapLease_MVC` vào `WebAdmin`, bao gồm `Controllers`, `Data`, `Models`, `Views`, `ViewModels` (nếu có), `wwwroot`, `Program.cs`, `RentalCamera.csproj`, file cấu hình mẫu và các tệp mã nguồn cần thiết.

**Không chép**: `bin`, `obj`, `.vs`, `.vscode` có cấu hình cá nhân, `.env`, file chứa mật khẩu thật, log, file SQL backup và tệp tạm.

Không xóa hoặc di chuyển các thư mục Backend/Mobile sẵn có trong repository. Nếu `main` đã có `WebAdmin` hoặc dự án Web, cần so sánh trước khi ghi đè.

### 9.4. Thêm `.gitignore`

Tạo hoặc cập nhật `.gitignore` ở gốc repository, **giữ lại các quy tắc cũ** và bổ sung:

```gitignore
**/bin/
**/obj/
.vs/
.env
.env.*
!.env.example
**/appsettings.Local.json
**/appsettings.*.Local.json
*.user
*.suo
*.log
```

**Trước khi commit**, rà soát `appsettings.json` và `appsettings.Development.json`; xóa mật khẩu thật và dùng cấu hình mẫu/biến môi trường. `.gitignore` không tự xóa bí mật đã được Git theo dõi từ trước.

### 9.5. Kiểm tra thay đổi và push

```powershell
cd D:\SnapLease\SnapLease_Web
git branch --show-current
git status --short
git diff --stat
git add WebAdmin README_WEB.md .gitignore
git diff --cached --stat
git diff --cached --name-status
git commit -m "feat(web): add SnapLease admin MVC"
git push -u origin Web
```

**Trước khi chạy `git commit`, kiểm tra `git diff --cached --name-status`:** không được có các file không chủ ý từ `RentalCamera.Api/`, `Database/`, `mobile/` hoặc thư mục khác của nhóm.

Nếu Git báo `nothing to commit`, kiểm tra bạn đã chép đúng tệp và `.gitignore` có đang loại trừ nhầm mã nguồn không.

Nếu `git push` bị từ chối vì nhánh đã có commit mới, **không dùng `--force`**. Thực hiện `git fetch origin`, kiểm tra `git status`, rồi tích hợp thay đổi trên nhánh `Web` một cách có kiểm soát; nếu có xung đột, trao đổi với người phụ trách trước khi resolve.

## 10. Quy trình cập nhật Web hằng ngày

Chỉ làm việc trên nhánh `Web`:

```powershell
cd D:\SnapLease\SnapLease_Web
git switch Web
git pull --ff-only origin Web
# Chỉnh sửa và chạy thử mã nguồn Web
git status --short
git add WebAdmin
git diff --cached --name-status
git commit -m "fix(web): update device management"
git push origin Web
```

**Khi nhiều thành viên cùng sửa Web:** nên tạo nhánh tính năng từ `Web` như `feature/web-device-edit`, sau đó mở Pull Request **vào `Web`**, không mở vào `backend` hoặc `mobile`.

Ví dụ:

```powershell
git switch Web
git pull --ff-only origin Web
git switch -c feature/web-device-edit
# Chỉnh sửa, kiểm tra và commit
git add WebAdmin
git commit -m "feat(web): improve device edit"
git push -u origin feature/web-device-edit
```

Sau đó tạo Pull Request: `feature/web-device-edit` → `Web`.

## 11. Nguyên tắc tránh xung đột với Backend và Mobile

1. **Web** chỉ sửa code Web và tài liệu Web. Backend/Mobile sửa trong nhánh và thư mục phụ trách.
2. **Không `git push --force`** lên `main`, `backend`, `mobile`, `Web`.
3. **Không merge toàn bộ nhánh `backend` vào `Web`** chỉ để chạy API; chạy Backend ở clone/thư mục riêng. Nếu cần đồng bộ hợp đồng API, phối hợp qua Pull Request có review.
4. Trước khi commit, luôn chạy `git status` và `git diff --cached --name-status`.
5. Khi muốn tích hợp lên `main`, tạo Pull Request `Web` → `main`, để nhóm review xung đột và thay đổi cấu hình.
6. Không commit mật khẩu, `.env`, connection string thật, khóa Cloudinary, VNPAY, OTP hoặc thông tin tài khoản.
7. **Nhánh riêng giảm va chạm trong quá trình phát triển nhưng không đảm bảo không có merge conflict**; tách thư mục và review Pull Request là biện pháp bổ sung.

## 12. Các lệnh nhanh cho thành viên

**Terminal 1 — Backend**

```powershell
cd D:\SnapLease\SnapLease_Backend
docker compose up -d
docker compose ps -a
```

**Terminal 2 — Web** (tại thư mục chứa `RentalCamera.csproj`)

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet restore
dotnet build -p:UseAppHost=false
dotnet bin\Debug\net8.0\RentalCamera.dll --urls "http://localhost:5001"
```

**Địa chỉ truy cập:**

- Web Admin: http://localhost:5001
- Backend Swagger: http://localhost:5000/swagger
- SQL Server trong Docker: `localhost,14330` (SQL authentication, tài khoản `sa`, mật khẩu riêng trong `.env`)

---

*Tài liệu nội bộ cho nhóm SnapLease. Trước khi triển khai chính thức, cần kiểm thử đầy đủ chức năng, phân quyền, bảo mật cấu hình và quy trình sao lưu database.*
