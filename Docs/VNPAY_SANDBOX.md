# Tích hợp VNPAY-QR Sandbox

Phạm vi này dùng cho đồ án và không phát sinh tiền thật. Backend tự xây dựng URL theo đặc tả VNPAY 2.1.0, ký HMAC-SHA512 và chỉ cập nhật giao dịch từ IPN hợp lệ.

## 1. Đăng ký Sandbox

Đăng ký tại <https://sandbox.vnpayment.vn/devreg/> để nhận:

- `TmnCode`
- `HashSecret`

Không commit `HashSecret` lên GitHub và không đưa khóa này cho Flutter.

## 2. Cấu hình `.env`

```dotenv
VNPAY_ENABLED=true
VNPAY_TMN_CODE=MA_SANDBOX_DUOC_CAP
VNPAY_HASH_SECRET=KHOA_SANDBOX_DUOC_CAP
VNPAY_PAYMENT_URL=https://sandbox.vnpayment.vn/paymentv2/vpcpay.html
VNPAY_RETURN_URL=https://ten-mien-cong-khai/api/thanh-toan/vnpay/return
VNPAY_IPN_URL=https://ten-mien-cong-khai/api/thanh-toan/vnpay/ipn
VNPAY_MOBILE_CALLBACK_URL=rentalcamera://payment-result
VNPAY_EXPIRATION_MINUTES=15
```

`IPN URL` phải dùng HTTPS và truy cập được từ Internet. URL này được khai báo với VNPAY khi cấu hình merchant. `ReturnUrl` có thể là App Link/Web Link, nhưng cấu hình mặc định của dự án trỏ về API để dễ kiểm thử.

## 3. Luồng gọi API

1. Tạo thanh toán cọc với `phuongThuc = VI_DIEN_TU`.
2. Gọi `POST /api/thanh-toan/{maThanhToan}/vnpay`.
3. Mở `paymentUrl` trả về.
4. Thanh toán bằng dữ liệu test của VNPAY.
5. VNPAY gọi IPN; backend kiểm tra chữ ký, mã tham chiếu, số tiền và trạng thái hiện tại.
6. Flutter đọc lại `GET /api/thanh-toan/{maThanhToan}`.

## 4. Dùng trong ứng dụng Flutter

API không trả một ảnh hoặc chuỗi QR riêng. Vì URL thanh toán đã có
`vnp_BankCode=VNPAYQR`, trang do VNPAY cung cấp sẽ hiển thị luồng VNPAY-QR.
Flutter mở `paymentUrl` bằng WebView hoặc trình duyệt ngoài.

Sau khi VNPAY chuyển về Return URL, backend xác minh chữ ký rồi chuyển tiếp về
`VNPAY_MOBILE_CALLBACK_URL`. Deep link nhận các tham số `maThanhToan`,
`trangThai`, `maPhanHoiVnpay` và `callbackHopLe`. Flutter vẫn phải gọi lại API
chi tiết thanh toán vì trạng thái do IPN cập nhật mới là kết quả cuối cùng.

## 5. Quy tắc an toàn

- Số tiền luôn lấy từ bảng `ThanhToan`, không lấy từ request Flutter.
- `vnp_TxnRef` dùng `MaThanhToan`, duy nhất trong hệ thống.
- `vnp_BankCode` cố định là `VNPAYQR` cho phạm vi đồ án.
- Chỉ IPN hợp lệ được thay đổi trạng thái giao dịch.
- Return URL không cập nhật database.
- IPN lặp lại trả `RspCode = 02` và không xử lý giao dịch lần hai.
- IPN sai chữ ký trả `97`, sai số tiền trả `04`, không tìm thấy giao dịch trả `01`.

## 6. Cập nhật database cũ

Docker Compose tự chạy script `Database/07_add_vnpay_payment.sql`. Nếu cần chạy thủ công trong container:

```powershell
docker compose run --rm --no-deps --entrypoint /bin/bash db-init -lc '/opt/mssql-tools18/bin/sqlcmd -S sqlserver -U sa -P "$MSSQL_SA_PASSWORD" -C -I -b -i /database/07_add_vnpay_payment.sql'
```
