# SNAPLEASE — Giao diện xem hợp đồng theo ảnh mẫu

Ngày: 16/10/2026. Phạm vi: Flutter mobile. Không sửa Backend, DB, schema,
container, cấu hình môi trường, luồng ký/thu tiền hoặc package; không commit/push/stash.

## Màn hình và component

Vẫn dùng `ContractPage` tại `/contract/:id`. Trang cuộn chung cho mọi trạng thái:
thanh trạng thái chỉ đọc → tóm tắt → trạng thái hiện tại → timeline → nhận/trả và
chi nhánh → đầy đủ thiết bị/bàn giao → thanh toán → pháp lý/PDF → các bên → lưu ý.
Giữ nút “Theo dõi trạng thái” mở `/contract/tracking`, Back về chi tiết và tải lại.

Tái sử dụng `AppTheme`, `AppSizes`, `AppText`, `ContractTrackingSummaryCard`,
`ContractStatusBadge`, `CurrentContractStatusCard`, `ContractTrackingViewData`,
`ContractProgressTimeline`, `ContractHandoverCard`, `VerificationProgress`,
`ContractDetailCubit`, repository hợp đồng, service PDF và các route sẵn có.

Component mới:

- `ContractStatusSteps`: tách thanh trạng thái dùng chung với tracking; không có callback đổi trạng thái.
- `ContractSectionCard` / `ContractInfoTile`: khung và hàng thông tin dùng ở nhiều thẻ.
- `ContractPaymentCard`: tiền theo hợp đồng, các khoản thành công, khoản chờ/hoàn và số dư chưa xác định.
- `BranchMapIllustration`: hình đường phố trang trí, nhãn “Bản đồ minh họa”; không marker/tọa độ/chỉ đường giả.

Địa chỉ, chi nhánh, lịch, tiền và thiết bị lấy từ dữ liệu hợp đồng; không lấy nội
dung hợp đồng, bảo hiểm hay xác thực trong ảnh mẫu làm dữ liệu sản phẩm.
Không có ảnh sản phẩm từ API hợp đồng thì dùng icon máy ảnh, không ảnh mẫu.

## Các file thay đổi

| File trong rentcam | Nội dung |
| --- | --- |
| `lib/features/contract/presentation/contract_page.dart` | Bố cục, nút theo trạng thái, giữ lifecycle/refresh/ký/hủy và lối vào tracking |
| `lib/features/contract/data/contract_detail_data.dart` | Map thanh toán và metadata pháp lý/PDF đang có trong response |
| `lib/features/contract/services/contract_pdf_service.dart` | Chỉ thêm metadata vào `ContractModel` và giữ qua `copyWith`; phần sinh PDF giữ nguyên |
| `lib/features/contract/presentation/contract_preview_page.dart` | Dùng chung nguồn PDF qua Cubit/repository, xử lý cập nhật hợp đồng và dispose |
| `lib/features/contract/presentation/tracking/contract_tracking_page.dart` | Dùng component thanh trạng thái chung; giữ đọc Backend |
| `lib/features/contract/presentation/tracking/widgets/contract_tracking_summary_card.dart` | Tóm tắt mở rộng tùy chọn cho chi tiết; giữ chế độ gọn cho tracking/gia hạn |
| `lib/features/contract/presentation/tracking/widgets/contract_progress_timeline.dart` | Tên thẻ tùy chọn và thời gian xuống dòng để tránh tràn trên màn hẹp |
| `lib/features/contract/domain/models/contract_payment_summary.dart` | Mới: receipt và dữ liệu số dư bảo thủ, không thực hiện thu/hoàn tiền |
| `lib/features/contract/data/repositories/contract_document_repository.dart` | Mới: GET PDF đã lưu; chỉ sinh nội dung khi chưa phải bản ký |
| `lib/features/contract/presentation/bloc/contract_document_cubit.dart` | Mới: dùng chung việc tải tài liệu cho xem/tải/chia sẻ, gộp request đang chạy |
| `lib/features/contract/presentation/widgets/contract_section_card.dart` | Mới: hai component khung/hàng thông tin |
| `lib/features/contract/presentation/widgets/contract_payment_card.dart` | Mới: thẻ thanh toán |
| `lib/features/contract/presentation/widgets/branch_map_illustration.dart` | Mới: bản đồ minh họa tách riêng để thay bằng bản đồ thật sau này |
| `lib/features/contract/presentation/tracking/widgets/contract_status_steps.dart` | Mới: thanh trạng thái dùng chung |
| `test/contract_detail_layout_test.dart` | Điều chỉnh test bố cục/PDF cho nguồn byte PDF đã lưu |
| `test/contract_reference_layout_test.dart` | Mới: trạng thái/nút, thanh toán, PDF và màn nhỏ/chữ lớn |

Không sửa router, màn gia hạn, màn/Bloc thanh toán hoặc cơ chế tải ảnh.
Giữ các thay đổi local có sẵn ngoài những file nêu trên.

## Nút chính

| Trạng thái Backend | Nhãn | Đích / hành vi |
| --- | --- | --- |
| `CHO_BAN_GIAO` | Xem thanh toán | `/payment`, đúng `ContractModel` |
| `DANG_THUE` | Gia hạn thuê | `/contract/renewal`, đúng `ContractModel`; thẻ thanh toán còn có row Xem thanh toán |
| `CHO_HOAN_TRA` | Xem hợp đồng điện tử | `/contract/preview`, lấy PDF đã ký; vô hiệu hóa nếu API xác nhận thiếu file |
| `HOAN_THANH` | Đánh giá | Vô hiệu hóa; “Chức năng đánh giá sẽ được bổ sung” |
| `CHO_KY` | Ký và xác nhận | Giữ checkbox chấp nhận, route `/signature` và thao tác hủy hiện có |
| `DA_KY` | Các nhãn thanh toán hiện có | Giữ phân biệt thành công / chờ / chưa có cọc, route `/payment` |
| `DA_HUY` / chưa biết | Không tạo nút nghiệp vụ mới | Không ánh xạ sang bốn trạng thái sau phân bổ |

Gia hạn hiện có màn nhưng chưa nối API kiểm tra lịch/tính phí/gửi yêu cầu.
Lượt này chỉ điều hướng đúng màn; không thêm gửi yêu cầu, bỏ qua điều kiện Backend
hoặc giả gia hạn thành công. Backend hiện có API dự kiến/yêu cầu gia hạn để tích hợp ở lượt riêng.

Theo quyết định của người dùng, chưa triển khai form đánh giá. Backend đã hỗ trợ
đánh giá từng thiết bị theo `maChiTietHopDong`, chỉ khách sở hữu hợp đồng
`HOAN_THANH`, chống gửi trùng (409). Mobile cần bổ sung form và tích hợp
`POST /api/danh-gia`, `GET /api/danh-gia/cua-toi` ở lượt sau. Không dùng
`reviewMode` của trang dòng máy làm form đánh giá giả.

## Dữ liệu và giới hạn thanh toán

GET `/api/hop-dong/{id}` tiếp tục cung cấp `datTheoDongMay`, `chiTiet`,
`chiTiet[].anhBienBan`, lịch, chi nhánh và các bên.

Thông tin mới được giữ từ response hiện có:

- `thanhToan[]`: `maThanhToan`, `maHopDong`, `loaiThanhToan`, `trangThai`, `soTien`, `phuongThuc`.
- `tongTien`, `tongTienCoc`, `phuLuc[].tienCocBoSung`.
- `ngayKy`, `hinhThucKy`, `maBamTepPdf`, `daDongYDieuKhoan`, `phienBanDieuKhoan`.

Chỉ receipt `TIEN_COC` / `THANH_CONG` được cộng vào cọc đã trả. Deduplicate theo
mã thanh toán; không cộng attempt VNPAY, request tiền mặt chờ, khoản thất bại,
tiền thuê hoặc hoàn cọc. Phương thức và số tiền hiển thị từ receipt thực tế.
Các khoản thuê/phí thành công được hiển thị riêng theo loại, không bù với cọc.

Chỉ tính cọc còn thiếu cho hợp đồng đang hoạt động khi dữ liệu receipt đầy đủ,
không có hoàn cọc, không có cọc bổ sung từ phụ lục và không bị trả vượt mức.
Dữ liệu thiếu/malformed/mâu thuẫn không được coi là đã trả 0 đồng.
Hoàn cọc `CHO_THANH_TOAN` và `DA_HOAN` được hiển thị khác nhau; không đổi trạng thái receipt gốc.

**Điểm Backend cần thống nhất:** endpoint quyết toán hiện trừ cả cọc khỏi
tiền thuê/phí. Không dùng kết quả này làm số dư độc lập theo yêu cầu mobile.
API chi tiết chưa có số dư tiền thuê và tổng còn phải trả theo nghĩa đó, đồng thời
còn phí/phụ lục/quyết toán. Hai số dư này hiển thị “Chưa xác định”, không dùng
`tongTien + tongTienCoc` thay cho tiền còn nợ. Cần Backend cung cấp số dư có ý nghĩa
được thống nhất trước khi hiển thị con số chính xác. Chưa sửa Backend trong lượt này.

## PDF và dữ liệu chưa có

Xem và tải/chia sẻ bản ký cùng dùng GET `/api/hop-dong/{id}/tep-pdf`.
Backend hiện kiểm file với mã băm trước khi trả. Mobile kiểm phản hồi có header PDF
và không tự dựng PDF thay cho bản ký khi lỗi/thiếu file.
Áp dụng cả `CHO_HOAN_TRA`, và hợp đồng hủy có thời điểm ký thực tế.

Nếu `maBamTepPdf` được trả nhưng rỗng, giao diện báo chưa có bản ký và khóa thao tác bản ký.
Nếu metadata này không có trong response cũ thì cho thử endpoint thật; lỗi hiển thị trung thực.
Hợp đồng chưa ký vẫn dùng nội dung PDF từ service sẵn có, không gọi đó là bản ký.
Không mở ảnh chữ ký thay PDF, không tự đánh dấu xác thực định danh hay xác minh chữ ký số.

Ảnh bàn giao vẫn dùng cơ chế cũ: không gửi JWT sang host ngoài API, thumbnail,
dialog phóng to và Android Back; ảnh 5003 lỗi vẫn có trạng thái lỗi, không xóa/lọc bản ghi.
Không đổi thời gian, timezone, hạn trả hoặc trạng thái tại mobile.

## Kiểm chứng

- Analyze phần thay đổi và file chứa `ContractModel`: không có vấn đề ở lần chạy đã ghi nhận.
- Lần chạy song song đầu tiên dừng do Dart VM hết bộ nhớ. Chạy tuần tự khắc phục được.
- Bộ regression và render dùng fixture trong test, không dùng dữ liệu giả trong ứng dụng thật.
- Có kiểm tra nút theo bốn trạng thái, Back, hàng Xem thanh toán khi đang thuê,
  dữ liệu thành công/chờ/thất bại/thiếu/hoàn, PDF đúng ID/đúng byte/409/HTML,
  nhiều serial, 320px, cỡ chữ 2x và SafeArea. Các regression refresh/foreground,
  chống phản hồi cũ, ảnh/dialog/Back và thanh toán vẫn chạy.
- Ảnh render giao diện và log kiểm tra cục bộ nằm trong `.dart_tool/contract-reference-layout-before/`
  (ignored; không phải dữ liệu chạy thật hoặc artefact cần commit).
- Hai lần build lên Samsung đều thất bại vì hết bộ nhớ Dart/Java. Lần thứ hai đã
  thử bỏ widget-creation tracking và DDS bằng tham số lệnh, không đổi file cấu hình.
  Chưa cài được bản mới; điện thoại vẫn có bản cũ. ADB nhận Samsung SM-A276B,
  reverse 5001 đã thiết lập, GET `http://127.0.0.1:5001/api/health` trả 200.
- Chưa xác nhận trên điện thoại đủ mọi trạng thái, ảnh thật/zoom, mở và tải/chia sẻ
  PDF đã ký sau thay đổi. Không kết luận ký, thanh toán, gia hạn hoặc bàn giao end-to-end đạt.

Kết quả cuối: **73 test chức năng/regression + 1 test render = 74 kiểm tra đạt**.
Analyze toàn bộ các phần thay đổi (gồm file chứa `ContractModel`) không có vấn đề.
`git diff --check` các file tracked đã sửa không báo lỗi khoảng trắng.
So sánh bản gốc trước lượt này xác nhận phần `ContractPdfService` sinh PDF giữ
nguyên nội dung; chỉ phần model trong cùng file được bổ sung.

Lệnh regression, chạy tuần tự để giảm bộ nhớ:

```powershell
Set-Location 'D:\KhoaLuan\Mobile\rentcam'
flutter test --no-pub --concurrency=1 test/contract_detail_layout_test.dart test/contract_reference_layout_test.dart test/contract_handover_test.dart test/contract_navigation_back_test.dart test/payment_feature_test.dart
```

Sau khi giải phóng đủ bộ nhớ cho công cụ phát triển, cài/chạy để kiểm tra thật:

```powershell
Set-Location 'D:\KhoaLuan\Mobile\rentcam'
& 'C:\Users\ASUS\AppData\Local\Android\sdk\platform-tools\adb.exe' -s R5GL66JBAEA reverse tcp:5001 tcp:5001
flutter run --no-pub -d R5GL66JBAEA --dart-define=BASE_URL=http://127.0.0.1:5001
```

Trên điện thoại cần kiểm tra lại chi tiết → tracking → Back; kéo refresh và
background/foreground; ảnh đúng serial, zoom/đóng/Android Back; Xem bản ký và
tải/chia sẻ PDF đúng hợp đồng; nút cuối trang không bị thanh Android che.
Không dùng việc chạy fixture hoặc mở đúng route để kết luận nghiệp vụ đã hoàn tất.
