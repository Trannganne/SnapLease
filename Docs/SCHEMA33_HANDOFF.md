# Backend33 — bàn giao source để tiếp tục kiểm tra

## Git handoff branch

The source handoff branch is `feature/backend-schema33-handoff`, based only on `4f4d4af0155b84dd850d16c0b25702d02965bf73`. No unstaged/untracked files were merged from the original working tree. After the owner publishes it, teammates can clone/pull this branch from `https://github.com/Trannganne/SnapLease.git` and follow the independent .NET8/SQL Server setup below.

All103 approved files are present. The branch intentionally retains45 unchanged baseline files, including the15 former deletion proposals, so existing legacy references are not broken. They are historical/unused for33, not additional initialization steps. The complete ledger is in SCHEMA33_SQL_INVENTORY.md. Only the5 Schema33 SQL are the installation package; do not execute inherited root SQL, compose.yaml or old API5000 test scripts. The8 inherited REVIEW guides keep their historical business/API content but are not the33 setup contract.

11 whitespace errors in6 C# files were removed in this worktree only; all non-whitespace bytes in those files match the trial. BUILD PASS remains the recorded .NET8.0.425 result before cleanup. BUILD AFTER CLEANUP NOT_RUN; DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. No Docker/database/API or new build was run for this handoff. This branch is for Backend review/testing on a separate machine, not evidence of a working deployed system.

The6 inherited test-script password literals were checked statically: each is an input for registering a UUID-named synthetic test account and then logging in as that same account. No real provider secret was identified. These scripts remain unused, were not executed, and no runtime account validity is claimed. Existing Git ancestry is retained; no file deletion/history rewrite is used to claim that a historical secret has been removed.

Phạm vi là backend trial33, .NET8/EF Core8/SQL Server2022, dùng đúng database `RentalCameraDb30_Test`. Source này bắt buộc môi trường `Schema33Trial`, provider giả, jobs/push/chatbot tắt. Chưa phải cấu hình production hoặc bản chuyển môi trường demo.

## Ngoại lệ SMTP OTP ký hợp đồng được duyệt riêng

Profile mặc định vẫn Fake. Một môi trường demo được người quản lý duyệt có thể đặt
`ContractOtpEmail:Mode=SmtpDemo`, `SmtpApproved=true` và `AllowedRecipient` là duy nhất
email thử đã được duyệt. `Schema33Trial:ProviderMode` vẫn phải là `Fake`; không đổi
sang Development/Production hoặc bỏ guard để bật SMTP. Mọi binding database,
PackageApproved, login runtime riêng, payment giả/URL loopback và các cờ tắt
jobs/push/chatbot/OTP response/auth-token response vẫn bắt buộc như trước.

Chỉ POST `/api/hop-dong/{id}/yeu-cau-ky` dùng provider có key `ContractSigningOtp`.
Provider mặc định, OTP phụ lục và email xác minh/quên mật khẩu vẫn dùng mailbox giả.
Người nhận lấy từ `KhachThue.Email` của khách hàng sở hữu hợp đồng; allowlist chỉ
kiểm tra email này, không thay thế người nhận hoặc nhận địa chỉ từ Flutter.
`SmtpContractOtpEmailSender` hiện có được tái sử dụng, không đổi HTTP contract/PDF/
điều khoản/OTP hoặc điều kiện ký.

Cấu hình `Email` phải bật, có Host, Port=587, UseSsl=true (STARTTLS), Username,
Password và FromAddress trùng Username. Không tắt kiểm tra chứng chỉ. Guard từ chối
profile chưa duyệt, email sai định dạng hoặc thiếu `ElectronicSignature:Pepper`.
Chỉ truyền bí mật bằng môi trường tiến trình (`Email__Password`,
`ElectronicSignature__Pepper`), không ghi vào source, ví dụ JSON, `.env` hoặc log.
Credential và Pepper được giữ ngoài Git trong runtime riêng; nếu dùng DPAPI Windows,
launcher phải chạy bằng đúng user/máy đã mã hóa. Pepper sinh ngẫu nhiên 32 byte một
lần rồi tái sử dụng, không đổi mỗi lần build/restart. Quản trị Docker có thể xem env
container, nên credential chỉ dùng cho môi trường demo được kiểm soát.

Email trial chỉ được đổi sau khi duyệt đúng tài khoản qua PUT `/api/auth/email` bằng
phiên xác thực của tài khoản đó. API xóa mốc xác minh email và tăng phiên bản bảo mật;
khách hàng đăng nhập lại. Không tự đánh dấu email đã xác minh hoặc sửa seed/schema.

Kiểm tra cô lập bằng `tests/Schema33Regression --contract-smtp-checks` dùng capture
sender, không gọi SQL/HTTP/SMTP. Build/publish chỉ cập nhật API trial, giữ nguyên SQL
container/volume/database, `.keys`, PDF và storage; không chạy lại package. Health và
Swagger chỉ chứng minh startup/route; việc Gmail nhận thư và ký thành công phải do
người thử tự yêu cầu OTP/xác nhận trên điện thoại. Không tự gửi thư kiểm thử.

## Bằng chứng của đợt tiếp tục 27/10/2026

| Kiểm tra | Trạng thái |
|---|---|
| Backend build bằng SDK8.0.425 | PASS trước đợt dọn; 0 lỗi, 0 cảnh báo. Không build lại sau khi dọn |
| Khai báo EF source |33 bảng/376 scalar theo evidence đợt chuẩn bị; chưa thay thế kiểm model runtime |
| Model EF runtime/DDL so với model | Chưa có kết quả; lệnh Docker đang chờ đã được ngắt khi daemon không phản hồi |
| Database/DDL/seed hậu kiểm | NOT_RUN trong đợt này; chưa gửi lệnh DDL/seed |
| API SMOKE | NOT_RUN; `http://127.0.0.1:5003` chỉ là cổng dự kiến |
| Toàn bộ regression, tải/đồng thời, nghiệp vụ sâu | NOT_RUN theo phạm vi bàn giao |

Log build nằm ngoài gói source tại evidence của máy thực hiện. Không gán kết quả compiler Roslyn cũ cho build SDK8. Người dùng đã chọn bàn giao source trước, không chờ Docker hoặc chạy lại SQL/runtime: trạng thái `SOURCE_HANDOFF_READY`, kèm `DATABASE/API NOT_RUN`. Chưa đạt điều kiện READY_FOR_BACKEND_REVIEW đầy đủ có DB/runtime.

Đợt dọn chỉ thay hướng dẫn, link và danh sách gói; không sửa C# ứng dụng, csproj, DDL33, seed hoặc API contract. BUILD PASS là kết quả đã ghi nhận trước khi dọn, không phải xác minh build mới. DATABASE NOT_RUN; API SMOKE NOT_RUN; REGRESSION NOT_RUN. Không chạy Docker/SQL/ứng dụng trong đợt này.

## Dựng môi trường độc lập

1. Cài SDK .NET8 và SQL Server2022; giữ nguyên phiên bản package trong csproj. Tạo riêng database trống tên `RentalCameraDb30_Test` trên môi trường của người nhận. Không dùng database cũ và không chạy Compose/db-init/migration lịch sử để dựng33.
2. Dùng `Database/Schema33/README.md`: xác minh metadata server/database trống, đối chiếu model EF, kiểm SHA256 manifest, áp duy nhất schema33 rồi seed catalog và hậu kiểm. Schema/seed tự quản lý transaction; không bọc thêm transaction. Khi lỗi/timeout, đọc lại metadata và log trước mọi hành động; không replay hoặc DROP/recreate.
3. Cấp login riêng cho trial, chỉ user của database này và quyền cần thiết trên schema dbo; runtime từ chối `sa`/Integrated Security. Không cấp quyền tạo DB/DDL cho runtime. Credential quản trị cài đặt và credential ứng dụng là hai vai trò riêng.
4. `dotnet restore RentalCamera.Api/RentalCamera.Api.csproj`, sau đó `dotnet build RentalCamera.Api/RentalCamera.Api.csproj --no-restore`. Các lệnh này chạy ở thư mục backend, không cần trial/tools của máy tác giả. NuGet phải truy cập được nguồn package của người nhận hoặc cache tương ứng.
5. `dotnet publish RentalCamera.Api/RentalCamera.Api.csproj --no-restore -o <thư-mục-publish-riêng>`. Tạo một thư mục runtime riêng và chép mẫu `RentalCamera.Api/appsettings.Schema33Trial.example.json` vào đó dưới tên `appsettings.Schema33Trial.json`. Điền connection riêng (database30, login riêng), ExpectedDataSource khớp connection và thư mục PDF riêng; chỉ bật PackageApproved sau khi các bước DB/model đạt. Không chép cấu hình live, merchant, khóa, dữ liệu hoặc Docker volume của máy tác giả.
6. Đặt `ASPNETCORE_ENVIRONMENT=Schema33Trial`, `ASPNETCORE_URLS=http://127.0.0.1:5003`. Chạy `dotnet <thư-mục-publish-riêng>/RentalCamera.Api.dll --contentRoot <thư-mục-runtime-riêng>`. Kiểm cổng trống trước khi chạy. `.keys` được tạo trong content root; ảnh giả ở `Storage/schema33-fake-images` dưới thư mục publish. Cả hai thư mục phải ghi được và nằm ngoài Git.
7. Kiểm `GET /api/health`, Swagger `/swagger`, rồi smoke API theo mục dưới. Health không truy vấn DB và không đủ để kết luận API–DB hoạt động.

`Database/Schema33/Invoke-Schema33Package.ps1` và `approval.template.json` đi kèm bộ cài. Chúng không tự tìm credential hoặc cấu hình của tác giả. Approval template mặc định false; authorization của người quản lý môi trường phải được phản ánh bằng binding/hash đúng trước khi chạy. Không cần duyệt lại nghiệp vụ33 đã chốt trong phiên tác giả.

PowerShell runner đã được phân tích cú pháp nhưng máy tác giả chặn execute theo policy; cần môi trường cho phép chạy script hợp lệ của người nhận. Model checker có chế độ `dotnet run --project tests/Schema33Regression -- --model-output <thư-mục-riêng>` để xuất model/DDL EF mà không mở DB; các thay đổi export mới chưa được compile/execute sau sự cố Docker. Schema/CatalogSeed vẫn bị runner khóa đến khi các kiểm tra còn thiếu hoàn thành.

## Smoke cần hoàn thành sau khi hạ tầng phản hồi

Chỉ dùng tài khoản/giấy tờ giả `TR33` từ seed, không gửi email/FCM/OTP/provider thật. Đăng nhập `POST /api/auth/login`; giữ Bearer token trong bộ nhớ, không ghi response login vào log. Đọc catalog `GET /api/dong-may`, availability `GET /api/lich-trong` với giờ địa phương Việt Nam không có Z/offset. Dùng khoảng tương lai trong giờ08–20.

Tạo giữ chỗ `POST /api/giu-cho/thue-ngay` với header `Idempotency-Key` riêng và body `maCuaHang`, `maDongMay`, `soLuong`, `ngayBatDau`, `ngayKetThuc`; xác nhận `POST /api/giu-cho/{maGiuCho}/xac-nhan-thue`, sau đó `GET /api/hop-dong/{maHopDong}` và đọc lại dữ liệu DB. Đối chiếu ID selection/version/snapshot; lưu mã thực thể và HTTP status đã khử dữ liệu nhạy cảm. POST bị timeout phải đối soát trước, không gửi lại tự động. Không tạo link/callback thanh toán để thay smoke cơ bản.

FixtureSeed ở tools là công cụ thử nghiệm riêng, chưa được execute/kiểm chứng và không nằm trong điều kiện smoke. Nó gọi endpoint delegate trong tiến trình; kết quả helper không thay HTTP smoke qua runtime thật. GET IPN cũng ghi tài chính; công cụ đã giữ PendingOperation cho mọi lần gọi delegate đến khi biết kết quả.

## API cho Web/Mobile và phần còn mở

Đọc [SCHEMA33_API_CHANGES.md](SCHEMA33_API_CHANGES.md). Swagger từ chính runtime33 sau khởi động là hợp đồng route/body hiện hành. Mobile/Web chưa được sửa hoặc kiểm tương thích. Bug Mobile mapping `CHO_HOAN_TRA` đã biết vẫn còn ngoài phạm vi.

Chưa kiểm dòng tiền/nhận trả/gia hạn/hủy/no-show/ACK/đánh giá xuyên suốt, tải/concurrency/locking, PDF/ảnh, callback/provider hoặc thiết bị thật. Không ghi PASS cho các phần này. Giờ08–20/TTL20 và nghiệp vụ đã chốt được giữ trong source; phải kiểm runtime sau.

Không tự commit/merge/push. Danh sách đề xuất push được xuất riêng cùng diff và hash để chủ dự án duyệt. Trial không có `.git`; không coi nó là nhánh đã tích hợp hoặc đã push.

Danh mục KEEP/ARCHIVE/REVIEW, nguồn gốc SQL và vị trí/hash archive: [SCHEMA33_SQL_INVENTORY.md](SCHEMA33_SQL_INVENTORY.md). Danh sách Markdown, file bàn giao và đề xuất thay đổi Git: [SCHEMA33_DELIVERY_FILES.md](SCHEMA33_DELIVERY_FILES.md). File REVIEW còn nguyên nội dung nghiệp vụ để đối chiếu; chỉ sửa link lịch sử và thêm nhãn cảnh báo, không đưa hướng dẫn cũ vào quy trình triển khai mặc định. Những file đã có thay thế về source vẫn chưa được coi là đã thay thế thành công trên DB thật.
