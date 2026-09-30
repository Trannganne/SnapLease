# Backend API Rental Camera

Đây là gói Backend tối giản để bàn giao và đưa lên Git. Gói chỉ chứa mã nguồn API, bộ SQL 20 bảng, cấu hình mẫu an toàn và tài liệu hướng dẫn. Không có thư mục build, khóa đăng nhập, tệp tạm, tài liệu khóa luận hoặc dữ liệu cá nhân từ máy phát triển.

## Cấu trúc

```text
Backend_Api/
|-- RentalCamera.Api/   Ma nguon ASP.NET Core 8
|-- Database/           SQL tao database, du lieu mau va truy van kiem tra
|-- Docs/               Tai lieu Word ban giao
|-- NuGet.Config        Nguon goi nuget.org
|-- .gitignore          Loai tru build, khoa va cau hinh cuc bo
`-- README.md           Huong dan nhanh
```

## Yêu cầu

- .NET SDK 8
- SQL Server và SQL Server Management Studio
- Git nếu cần chia sẻ mã nguồn

## Khởi tạo cơ sở dữ liệu

Với database mới, mở SQL Server Management Studio và chạy theo thứ tự:

1. `Database/01_schema.sql`
2. `Database/02_sample_data.sql`
3. Dùng `Database/03_required_queries.sql` để kiểm tra dữ liệu và các truy vấn nghiệp vụ.

`04_repair_existing_demo.sql` và `05_add_store_to_cart.sql` chỉ dành cho database demo cũ cần sửa hoặc bổ sung. Không chạy lại `01_schema.sql` và `02_sample_data.sql` trên database đang có dữ liệu cần giữ.

## Cấu hình kết nối

Mở `RentalCamera.Api/appsettings.json` và đổi `Server=localhost` theo SQL Server của máy. Ví dụ SQL Express thường dùng `Server=localhost\\SQLEXPRESS`.

Nếu dùng tài khoản SQL, không ghi mật khẩu vào tệp chia sẻ. Trong PowerShell, đặt chuỗi kết nối bằng biến môi trường cho phiên chạy hiện tại:

```powershell
$env:ConnectionStrings__RentalCamera = 'Server=localhost;Database=RentalCameraDb20;User Id=TEN_DANG_NHAP;Password=MAT_KHAU;Encrypt=True;TrustServerCertificate=True'
```

## Chạy API

Tại thư mục `Backend_Api`:

```powershell
dotnet restore .\RentalCamera.Api\RentalCamera.Api.csproj
dotnet run --project .\RentalCamera.Api\RentalCamera.Api.csproj --urls "http://0.0.0.0:5000"
```

Kiểm tra:

- Health: `http://localhost:5000/api/health`
- Swagger: `http://localhost:5000/swagger`
- OpenAPI: `http://localhost:5000/swagger/v1/swagger.json`

`/api/health` chỉ xác nhận ứng dụng đã chạy. Hãy gọi thêm `/api/danh-muc` hoặc `/api/dong-may` để xác nhận kết nối SQL Server.

## Kết nối Web và Mobile

- Web chạy cùng máy: `http://localhost:5000`
- Android Emulator: `http://10.0.2.2:5000`
- Điện thoại thật: `http://DIA_CHI_IP_LAN_CUA_MAY_CHAY_API:5000`

Điện thoại và máy chạy API phải cùng mạng. Cho phép cổng 5000 trong Windows Firewall khi cần. Web chạy ở origin khác phải được thêm chính xác vào `Cors:AllowedOrigins`, sau đó khởi động lại API. Ứng dụng mobile native không chịu chính sách CORS của trình duyệt.

## Xác thực và phân quyền

- `POST /api/auth/register` chỉ tạo khách hàng.
- `POST /api/auth/login` trả Bearer token có hạn 1 giờ.
- Token là token nội bộ ASP.NET Core Data Protection, không phải JWT; frontend không tự giải mã.
- Gửi token bằng `Authorization: Bearer <accessToken>`.
- Các vai trò chính: `KHACH_HANG`, `NHAN_VIEN`, `ADMIN`.
- Không đưa token, mật khẩu hoặc tệp `.keys/*.xml` lên Git.

Để đặt mật khẩu cho tài khoản nhân viên mẫu trên database thử nghiệm:

```powershell
dotnet run --project .\RentalCamera.Api\RentalCamera.Api.csproj -- set-password nhanvien01
```

## Quy ước phản hồi

- `200`, `201`, `204`: thành công; `204` không có JSON body.
- `400`: dữ liệu đầu vào không hợp lệ.
- `401`: thiếu hoặc hết hạn token.
- `403`: đúng tài khoản nhưng không đủ quyền.
- `404`: không tìm thấy tài nguyên.
- `409`: xung đột trạng thái hoặc lịch thuê.
- `429`: gọi đăng nhập quá nhanh.
- `500`: kiểm tra log API và cấu hình SQL Server.

Ngày giờ dùng giờ địa phương Việt Nam dạng `yyyy-MM-ddTHH:mm:ss`, không tự thêm `Z`. Giá và tiền cọc do server tính; giao diện không tự tính để ghi ngược vào hệ thống.

## Đưa lên Git

Có thể đưa Backend, Web và Mobile vào cùng một repository theo cấu trúc:

```text
RentalCamera/
|-- backend/    Noi dung cua thu muc Backend_Api
|-- web/
|-- mobile/
`-- docs/
```

Mỗi người làm trên branch riêng và tạo pull request vào `develop`. Không commit `bin`, `obj`, `.keys`, tệp cấu hình có mật khẩu hoặc dữ liệu cá nhân thật.

Tài liệu chi tiết cho hai bạn phụ trách Web và Mobile nằm trong `Docs/Tai lieu ban giao Backend API Rental Camera.docx`.

