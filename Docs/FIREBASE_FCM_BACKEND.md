# Firebase Cloud Messaging cho backend

Tài liệu này mô tả cách cấu hình và kiểm thử Firebase Cloud Messaging (FCM) cho API SnapLease. Không lưu service-account, private key hoặc file `.env` thật trong Git.

## Phạm vi

- Firebase project: `snaplease-b1256`
- Backend: ASP.NET Core 8, Firebase Admin .NET SDK
- Đích gửi: Firebase Installation ID (FID)
- API lưu thông báo vẫn trả thêm `eventCode`, `targetType` và `targetId` để mobile điều hướng.

## 1. Chuẩn bị service-account

Mỗi thành viên backend tự tải service-account JSON từ Firebase Console và lưu ngoài repository. Ví dụ trên Windows:

```text
D:/SnapLease-Secrets/snaplease-firebase-admin.json
```

Không gửi file này qua Git, chat nhóm hoặc tài liệu dùng chung.

## 2. Cấu hình môi trường

Sao chép `.env.example` thành `.env`, sau đó điền tối thiểu:

```env
FIREBASE_PROJECT_ID=snaplease-b1256
FIREBASE_ADMIN_CREDENTIALS_FILE=D:/SnapLease-Secrets/snaplease-firebase-admin.json
```

`FIREBASE_ADMIN_CREDENTIALS_FILE` là đường dẫn trên máy host. Docker Compose mount file này vào container tại `/run/secrets/firebase_admin` và đặt `GOOGLE_APPLICATION_CREDENTIALS` trỏ tới đường dẫn đó.

## 3. Khởi động backend

```powershell
docker compose config --quiet
docker compose build api
docker compose up --detach --force-recreate api
docker compose ps -a
```

Kết quả mong đợi:

- `rentalcamera-api`: `Up`
- `rentalcamera-sql`: `healthy`
- `rentalcamera-db-init`: `Exited (0)`

Kiểm tra:

```powershell
docker exec rentalcamera-api printenv GOOGLE_APPLICATION_CREDENTIALS
docker exec rentalcamera-api sh -c 'test -f /run/secrets/firebase_admin && echo FIREBASE_CREDENTIAL_FOUND || echo FIREBASE_CREDENTIAL_MISSING'
Invoke-WebRequest -UseBasicParsing "http://localhost:5000/api/health" | Select-Object StatusCode
```

Giá trị mong đợi lần lượt là `/run/secrets/firebase_admin`, `FIREBASE_CREDENTIAL_FOUND` và HTTP `200`.

## 4. API đăng ký thiết bị

Tất cả endpoint dưới đây yêu cầu access token của tài khoản đang đăng nhập.

### Đăng ký hoặc cập nhật FID

```http
POST /api/thong-bao/fcm-token
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{
  "fid": "FIREBASE_INSTALLATION_ID",
  "platform": "ANDROID",
  "deviceId": "OPTIONAL_DEVICE_ID"
}
```

`platform` nhận `ANDROID` hoặc `IOS`. Response trả `id`; mobile lưu giá trị này để hủy đăng ký khi đăng xuất.

### Hủy đăng ký

```http
DELETE /api/thong-bao/fcm-token/{id}
Authorization: Bearer <accessToken>
```

Endpoint chỉ vô hiệu hóa FID thuộc tài khoản hiện tại.

## 5. Dữ liệu điều hướng

Thông báo FCM và bản ghi `ThongBao` có thể chứa:

| Trường | Ý nghĩa |
| --- | --- |
| `eventCode` | Mã sự kiện ổn định để mobile phân loại |
| `targetType` | Loại đối tượng cần mở |
| `targetId` | Mã đối tượng cần mở |

| Sự kiện | `eventCode` | `targetType` |
| --- | --- | --- |
| Tạo hợp đồng chờ ký | `CONTRACT_CREATED` | `HOP_DONG` |
| Kết quả xác minh giấy tờ | `IDENTITY_VERIFICATION_RESULT` | `GIAY_TO_TUY_THAN` |
| Thiết bị sẵn sàng bàn giao | `CONTRACT_READY_FOR_HANDOVER` | `HOP_DONG` |
| Hợp đồng sắp đến hạn trả | `CONTRACT_RETURN_DUE_SOON` | `HOP_DONG` |
| Hợp đồng đã quá hạn trả | `CONTRACT_RETURN_OVERDUE` | `HOP_DONG` |

## 6. Phối hợp với mobile

Mobile phải dùng cùng Firebase project, lấy Firebase Installation ID (FID), rồi gọi API đăng ký sau khi đăng nhập. Khi đăng xuất, gọi API hủy đăng ký bằng `id` đã nhận. Khi người dùng bấm thông báo, mobile đọc `eventCode`, `targetType` và `targetId` để điều hướng.

Không dùng service-account JSON trong ứng dụng mobile. File này chỉ dành cho backend.

## 7. Kiểm thử gửi thật

Sau khi mobile đăng ký một FID thật, kích hoạt nghiệp vụ tạo hợp đồng hoặc xác minh giấy tờ, rồi xem log:

```powershell
docker logs --since 5m rentalcamera-api 2>&1 | Select-String -Pattern "FCM|Firebase|fail:|exception"
```

Log thành công có dạng:

```text
FCM tài khoản ...: thử 1, thành công 1, thất bại 0.
```

Không dùng FID giả để kết luận rằng cấu hình Firebase bị lỗi.
