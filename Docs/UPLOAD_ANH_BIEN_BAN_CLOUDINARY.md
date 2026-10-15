# Hướng dẫn upload ảnh biên bản lên Cloudinary

Tài liệu này dành cho Backend và Mobile khi kiểm thử chức năng lưu ảnh bàn giao, nhận lại hoặc hư hỏng của một chi tiết hợp đồng.

## 1. Luồng xử lý

1. Nhân viên chọn ảnh trong ứng dụng Mobile.
2. Mobile gửi file ảnh trực tiếp đến Backend bằng `multipart/form-data`.
3. Backend kiểm tra quyền, định dạng và dung lượng file.
4. Backend dùng khóa bí mật trên máy chủ để upload ảnh lên Cloudinary.
5. Cloudinary trả về URL HTTPS.
6. Backend lưu URL vào trường `AnhBienBan.DuongDanAnh` và trả bản ghi ảnh cho Mobile.

Mobile không cần upload thủ công lên Cloudinary, không nhập URL và tuyệt đối không chứa `CLOUDINARY_API_SECRET`.

## 2. Chuẩn bị tài khoản Cloudinary

1. Đăng ký hoặc đăng nhập tại <https://cloudinary.com/>.
2. Trong Cloudinary Console, mở phần thông tin API của Product Environment.
3. Lấy ba giá trị:
   - Cloud name
   - API Key
   - API Secret
4. Không gửi API Secret lên GitHub, ứng dụng Mobile hoặc nhóm chat công khai.

Mỗi thành viên có thể dùng tài khoản Cloudinary riêng để kiểm thử trên máy cá nhân. Môi trường dùng chung nên sử dụng một tài khoản do nhóm quản lý.

## 3. Cấu hình Backend

Mở PowerShell tại thư mục Backend:

```powershell
cd D:\Backend_Api
Copy-Item .env.example .env
```

Nếu `.env` đã tồn tại thì không cần sao chép lại. Mở `.env` và điền:

```env
CLOUDINARY_CLOUD_NAME=ten_cloud_cua_ban
CLOUDINARY_API_KEY=api_key_cua_ban
CLOUDINARY_API_SECRET=api_secret_cua_ban
CLOUDINARY_EVIDENCE_FOLDER=rental-camera/bien-ban
CLOUDINARY_MAXIMUM_MEGABYTES=10
```

Không thêm dấu ngoặc kép nếu giá trị không có yêu cầu đặc biệt. File `.env` đã được loại khỏi Git và không được commit.

## 4. Khởi động Backend

Nếu hệ thống chưa chạy:

```powershell
docker compose up -d --build
docker compose ps -a
```

Nếu hệ thống đang chạy và chỉ vừa thay đổi cấu hình Cloudinary:

```powershell
docker compose up -d --build api
docker compose logs --tail 100 api
```

Trạng thái mong đợi:

```text
rentalcamera-sql       Up (healthy)
rentalcamera-db-init   Exited (0)
rentalcamera-api       Up
```

Kiểm tra nhanh:

- Health: <http://localhost:5000/api/health>
- Swagger: <http://localhost:5000/swagger>

Nếu database trên máy được tạo từ phiên bản cũ và báo thiếu cột, chạy script cập nhật phù hợp trong thư mục `Database` trước khi kiểm thử. Với luồng thuê ngay hiện tại, kiểm tra `Database/migration_thue_ngay_final.sql`.

## 5. Chuẩn bị tài khoản nhân viên

API upload ảnh chỉ cho phép tài khoản có vai trò nhân viên hoặc quản trị viên.

Có thể đặt lại mật khẩu tài khoản mẫu:

```powershell
docker compose exec api dotnet RentalCamera.Api.dll set-password nhanvien01
```

Mật khẩu phải dài 8–128 ký tự và có chữ hoa, chữ thường, chữ số, ký tự đặc biệt.

Trong Swagger:

1. Mở `POST /api/auth/login`.
2. Đăng nhập bằng tài khoản nhân viên hoặc quản trị viên.
3. Sao chép `accessToken` trong kết quả.
4. Chọn nút **Authorize** ở đầu trang và dán token.

## 6. Kiểm thử upload trên Swagger

Mở endpoint:

```text
POST /api/chi-tiet-hop-dong/{id}/anh-bien-ban
```

Chọn **Try it out** và nhập:

| Trường | Bắt buộc | Giá trị ví dụ | Ý nghĩa |
|---|---:|---|---|
| `id` | Có | Mã chi tiết hợp đồng đang tồn tại | Chi tiết hợp đồng cần lưu ảnh |
| `loai` | Có | `BAN_GIAO` | Loại ảnh biên bản |
| `anh` | Có | Chọn file `.jpg`, `.png` hoặc `.webp` | File ảnh thực tế |
| `moTa` | Không | `Ảnh thân máy khi bàn giao` | Ghi chú cho ảnh |

Các giá trị `loai` nên dùng:

- `BAN_GIAO`: ảnh lúc giao thiết bị cho khách.
- `NHAN_LAI`: ảnh lúc nhận lại thiết bị.
- `HU_HONG`: ảnh ghi nhận hư hỏng hoặc bất thường.

Điều kiện của file:

- Định dạng: JPEG, PNG hoặc WEBP.
- Dung lượng tối đa mặc định: 10 MB.

Chọn **Execute**. Khi thành công, API trả mã `201 Created`. Trường `duongDanAnh` trong kết quả phải là URL HTTPS của Cloudinary, không phải đường dẫn local.

## 7. Kiểm thử bằng PowerShell

Thay `<ID_CHI_TIET_HOP_DONG>`, `<ACCESS_TOKEN>` và đường dẫn ảnh bằng dữ liệu thật:

```powershell
curl.exe -X POST "http://localhost:5000/api/chi-tiet-hop-dong/<ID_CHI_TIET_HOP_DONG>/anh-bien-ban" `
  -H "Authorization: Bearer <ACCESS_TOKEN>" `
  -F "loai=BAN_GIAO" `
  -F "anh=@C:\Users\HP\Pictures\ban-giao.jpg;type=image/jpeg" `
  -F "moTa=Anh thiet bi khi ban giao"
```

## 8. Mobile gọi API như thế nào

Mobile gửi một multipart request đến Base URL phù hợp:

- Android Emulator: `http://10.0.2.2:5000`
- Điện thoại thật cùng Wi-Fi: `http://<IP_LAN_MAY_BACKEND>:5000`

Request phải có:

- Header `Authorization: Bearer <accessToken>`.
- Trường chữ `loai`.
- Trường file `anh`.
- Trường chữ `moTa` nếu có.

Mobile chỉ sử dụng URL do Backend trả về để hiển thị ảnh. Mobile không gọi Cloudinary bằng API Secret.

## 9. Kiểm tra dữ liệu sau khi upload

Sau khi API trả `201`:

1. Mở URL trong `duongDanAnh` để xác nhận ảnh hiển thị được.
2. Vào Cloudinary Console, kiểm tra thư mục `rental-camera/bien-ban`.
3. Kiểm tra bảng `AnhBienBan`: bản ghi phải liên kết đúng chi tiết hợp đồng và lưu URL HTTPS.

## 10. Lỗi thường gặp

| Mã lỗi | Nguyên nhân thường gặp | Cách xử lý |
|---:|---|---|
| `400` | Thiếu file, sai loại file, file quá dung lượng hoặc `loai` không hợp lệ | Chọn JPEG/PNG/WEBP nhỏ hơn giới hạn và nhập đủ trường |
| `401` | Chưa gửi token hoặc token hết hạn | Đăng nhập lại và Authorize bằng token mới |
| `403` | Tài khoản không phải nhân viên/admin hoặc không thuộc cửa hàng phù hợp | Dùng đúng tài khoản và kiểm tra phân quyền |
| `404` | `id` chi tiết hợp đồng không tồn tại | Kiểm tra dữ liệu hợp đồng trong database |
| `502` | Cloudinary từ chối hoặc lỗi kết nối | Kiểm tra tên cloud, API key, API secret và log API |
| `503` | Backend chưa có cấu hình Cloudinary | Điền đủ biến `CLOUDINARY_*` trong `.env` rồi build lại API |

Xem log chi tiết:

```powershell
docker compose logs --tail 200 api
```

## 11. Tiêu chí xác nhận hoàn thành

- Swagger hiển thị trường chọn file `anh`.
- Nhân viên/admin upload được ảnh thật.
- API trả `201 Created`.
- `duongDanAnh` là URL HTTPS của Cloudinary.
- Ảnh mở được từ URL trả về.
- Bảng `AnhBienBan` lưu đúng URL và đúng chi tiết hợp đồng.
- Tài khoản khách hàng không được phép gọi API upload ảnh.
- Không có API Secret trong source code, Git hoặc ứng dụng Mobile.
