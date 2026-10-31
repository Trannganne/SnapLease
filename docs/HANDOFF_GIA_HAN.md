# Gia hạn mobile SNAPLEASE — 2026-10-16

## Phạm vi và dữ liệu bảo toàn
- Giữ thay đổi có sẵn, không commit/push/stash, không đổi Backend/schema/SQL/build config.
- Không POST gia hạn thực tế. Không ghi vào HD588670599EC646F8AD hoặc HDC1BF800950C74295A7.
- Đã đọc RULES.md, PROJECT_CONTEXT.md; tìm trong workspace không thấy AGENTS.md.
- Người dùng đồng ý thêm ô lý do trong thẻ chọn ngày; không thêm package.

## API đã đối chiếu
- Runtime: `http://127.0.0.1:5001/swagger/v1/swagger.json`, health OK.
- Docker inspect (chỉ xuất tên DB): `rentalcamera-api-test`, 5001 -> 8080, `RentalCameraDb20_Test`. Không gọi API 5000/DB chính.
- Source: `backend/RentalCamera.Api/Contracts/ContractFlowEndpoints.cs` (GET/POST 755+, quote 952+, duyệt 863+, chi tiết 209+), `Rental/AvailabilityService.cs`.
- GET `/api/hop-dong/{id}/du-kien-gia-han?thoiHanTraMoi=<ISO date-time>`.
  Response: `coTheGiaHan`, `lyDo`, `thoiHanTraHienTai`, `thoiHanTraMoi`, `soNgayGiaHan`, `chiPhiDuKien`. 200 khả dụng; 409 không khả dụng hoặc sai trạng thái.
- POST `/api/hop-dong/{id}/yeu-cau-gia-han` body `{thoiHanTraMoi, lyDoGiaHan, ghiChu:null}`.
  Lý do bắt buộc, trim, <=500 ký tự. Trả 201 với `maPhuLuc`, `maHopDong`, `thoiHanTraMoi`, `chiPhiPhatSinh`, `tienCocBoSung`, `lyDoGiaHan`, `ghiChu`, `trangThai:CHO_XAC_NHAN`, `soNgayGiaHan`, `thongBao`.
- Customer policy + tìm hợp đồng theo khách hiện tại. Không thuộc khách: 404; thiếu quyền customer: 403; chưa đăng nhập: 401. Validation `loi`, conflict có thể `loi` hoặc quote `lyDo`.
- GET `/api/hop-dong/{id}` có `phuLuc` để đọc tất cả yêu cầu/phụ lục. Location POST `/api/gia-han/{id}` KHÔNG có GET tương ứng dành cho khách; không sử dụng Location để đọc.
- GET `/api/hop-dong/cua-toi` không chứa phụ lục: repository đọc thêm chi tiết các hợp đồng DA_KY/CHO_BAN_GIAO/DANG_THUE khi refresh danh sách.

## Quy tắc thực tế / giới hạn Backend
- Cho phép DA_KY, CHO_BAN_GIAO, DANG_THUE. Không kiểm tra quá hạn theo đồng hồ trong quote/POST; mobile không tự bịa quy tắc chặn quá hạn. Không dùng hợp đồng quá hạn làm ca thành công thông thường.
- Gia hạn toàn bộ hợp đồng. Kiểm tra capacity theo dòng máy/số lượng trong ChiTietGiuCho, KHÔNG theo serial đã phân bổ. Đây là giới hạn Backend; mobile không khẳng định serial đang thuê đã được xác nhận trống.
- Kiểm tra toàn bộ khoảng [hạn hiện tại, hạn mới), loại hợp đồng hiện tại; lịch/hold chồng lấn dùng start < end và end > start. Không chỉ kiểm tra ngày kết thúc.
- Hạn mới > hạn hiệu lực. Hạn hiệu lực = max(ThoiGianTraDuKien gốc, các ThoiHanTraMoi của DA_XAC_NHAN).
- Phí = ceil(total days kéo dài), tối thiểu 1 ngày, nhân tổng DonGia*SoLuong của ChiTietGioHang, round 2 chữ số. Chỉ Backend tính.
- POST transaction Serializable, chặn nếu có CHO_XAC_NHAN. Gửi chỉ tạo phụ lục; nhân viên phải duyệt. Duyệt kiểm tra lại khả dụng và chuyển DA_XAC_NHAN, không ghi đè ThoiGianTraDuKien gốc. Không có bước thanh toán/ký phụ lục trong endpoint này, không tự tạo các bước đó.
- OpenAPI gọi kiểu date-time; source dùng DateTime/SQL datetime2 không có quy ước timezone thống nhất cho thời gian thuê. Mobile giữ clock/kind API, giữ giờ/phút/giây khi thay ngày; không tự +/-7 giờ với chuỗi không có timezone. Không suy quy tắc UTC của hold/payment sang ngày thuê.
- Không có API lịch tháng dành cho gia hạn và serial. Tái sử dụng AppAvailabilityCalendar ở chế độ fixedPickup, không gọi lịch dòng máy của đơn mới, không fan-out preview từng ngày, không bịa marks. Hiện chú thích giới hạn; ngày <= mốc bị khóa. Sau chọn luôn preview cả khoảng.

## File đã sửa / tạo trong tác vụ
- `lib/features/contract/domain/models/extension_models.dart` (mới): quote/error.
- `lib/features/contract/data/extension_submission_store.dart` (mới): marker SharedPreferences trước POST, chứa hợp đồng/ngày/lý do/ID đã biết; không chứa thông tin đăng nhập. Marker không tự gửi lại sau khởi động app.
- `lib/features/contract/data/repositories/contract_repository.dart`: preview/POST qua ApiClient hiện có, map lỗi, timeout/5xx kết quả chưa xác định.
- `lib/features/contract/presentation/renewal/contract_renewal_cubit.dart` (mới): fresh load, pending/approved, generation bỏ response cũ, guard POST, refresh và đối soát marker.
- `lib/features/contract/presentation/renewal/contract_renewal_page.dart`: giữ các thẻ, fee từ quote, lý do đã được đồng ý, dùng lịch chung, loading/error/pending, không tự đổi hạn/trạng thái.
- `lib/core/widgets/app_availability_calendar.dart`: fixedPickup opt-in; hành vi đặt thuê cũ giữ mặc định false. UI lịch gia hạn có mốc cố định và chú thích thiếu lịch khóa, không dùng lịch đặt mới.
- `lib/features/contract/services/contract_pdf_service.dart`: chỉ bổ sung metadata phụ lục/getter effectiveReturnDate/proposedReturnDate và giữ qua copyWith; không đổi tạo PDF, ký hoặc ngày hợp đồng gốc.
- `lib/features/contract/data/contract_detail_data.dart`: map phuLuc.
- `lib/features/contract/presentation/contract_page.dart`: lịch hiển thị hạn hiệu lực, truyền repository cho màn gia hạn khi mở bằng action.
- `lib/features/contract/presentation/tracking/contract_tracking_page.dart`: await quay về từ gia hạn rồi load lại.
- `lib/features/contract/presentation/tracking/models/contract_tracking_view_data.dart`: hạn trả từ phụ lục đã duyệt.
- `lib/features/contract/presentation/tracking/widgets/contract_tracking_summary_card.dart`: lịch hiệu lực và ngày đề nghị riêng.
- `lib/features/contract/data/contract_list_repository.dart`: fresh supplements cho hợp đồng có thể gia hạn, pending riêng.
- `test/contract_renewal_test.dart` (mới): race, invalid/conflict, gửi lặp, timeout/reopen/reconcile, refresh, pending/approved, DTO/error, token, list, calendar.
- `test/contract_detail_layout_test.dart`, `test/contract_handover_test.dart`, `test/contract_reference_layout_test.dart`: fake extends repository sau thêm methods, mock preferences cho navigation gia hạn.
- Route không thêm; reuse route `/contract/renewal` và action renewal có sẵn. List đã await/pop reload trước tác vụ.

## Kiểm thử / tiếp theo
- Lần analyze đầu phát hiện fake implements thiếu methods, đã sửa; có warning/info cũ ngoài phạm vi. Cần ghi kết quả analyze cuối ở dưới.
- Lần test đầu lỗi finder generic TableCalendar và test navigation dùng storage thật; đã sửa finder predicate, inject repository và mock storage.
- Lần test tiếp theo: 33/33 pass (renewal + reference layout). Đang chạy lại tập đầy đủ và bổ sung test list/token.
- Runtime chỉ audit OpenAPI/health và SELECT test DB, chưa E2E có token khách.
- SELECT chỉ đọc: chỉ có 2 DANG_THUE: HD08F9ABAE233E406BAF (hạn 2026-10-12), HD002 (2026-09-14), đều quá hạn tại 2026-10-16. Không có hợp đồng phù hợp để POST.
- Cần người dùng tạo hợp đồng test riêng bằng tài khoản khách trên app/Swagger 5001: nhận/trả tương lai, ký/cọc/bàn giao qua luồng hiện có để DANG_THUE; hạn trả còn tương lai, không CHO_XAC_NHAN. Sau đó preview và gửi 1 lần, kiểm tra pending và hạn cũ, quay về tracking/list; nhân viên duyệt bằng Swagger test nếu cần xác minh hạn hiệu lực.
- Điện thoại ADB: SM_A276B, R5GL66JBAEA. Cần build debug với BASE_URL=http://127.0.0.1:5001, adb reverse tcp:5001 tcp:5001, install -r; không chỉnh build config. Chưa ghi kết quả cài tại thời điểm tạo tài liệu.
- Giới hạn: danh sách cần thêm GET chi tiết cho hợp đồng còn gia hạn được vì list DTO thiếu phụ lục. Marker chỉ được tự gỡ khi đã đối soát hoặc nhận response chắc chắn; nếu mãi không xác minh được, liên hệ cửa hàng, không tự retry POST.

## Kết quả xác nhận cuối
- 74/74 test PASS trong 5 file: contract_renewal_test.dart (11 test), contract_handover_test.dart, contract_detail_layout_test.dart, contract_reference_layout_test.dart, contract_navigation_back_test.dart.
- Test tự động dùng fake/interceptor, không phải POST end-to-end. Có test bearer qua ApiClient, DTO/409/403/timeout, ngày sai, response sai thứ tự, lý do thiếu, double-submit, pending/approved, reload/list, marker qua mở lại màn, lịch fixed 390x844 và hồi quy marks/khoảng khóa của lịch đặt mới.
- Lịch đặt thuê test hành vi dùng viewport 800x900 để đủ chỗ cho font test; không coi đây là xác nhận layout mobile của đặt mới. Lịch gia hạn test 390x844; phát hiện tiêu đề tràn 0.25px, đã bọc Expanded trong hàng tiêu đề có sẵn.
- Analyze toàn repo: 0 error, 55 warning/info có sẵn ngoài mã gia hạn; exit 1 vì lint cũ. Analyze riêng 7 mục gồm thư mục renewal, repositories/model/store/lịch/test: No issues found sau sửa cuối.
- Đối chiếu thêm SELECT phụ lục đã duyệt: HD002 có hạn hiệu lực 2026-09-15 18:00 (gốc 2026-09-14); HD08F9ABAE233E406BAF hạn 2026-10-12, không phụ lục đã duyệt. Cả hai vẫn quá hạn, không POST.
- Build debug với BASE_URL=http://127.0.0.1:5001 đã PASS. Cài -r lên R5GL66JBAEA thành công, mở MainActivity Status: ok, adb reverse chỉ cổng 5001 cho tác vụ này. Đang build/cài lại sau sửa tiêu đề lịch cuối; kết quả bổ sung bên dưới.
- Màn gia hạn cũng refresh khi resume và khởi tạo lại Cubit nếu đổi contractId/repository; badge dùng trạng thái Backend thật.
- APK CUỐI (sau sửa co giãn tiêu đề): build PASS 67.5s, `adb install -r` Success trên SM_A276B / R5GL66JBAEA. Artifact: `build/app/outputs/flutter-apk/app-debug.apk`, BASE_URL=http://127.0.0.1:5001. Không thay đổi Gradle/manifest/api_config/pubspec trong tác vụ; các file đó đã dirty từ trước.
