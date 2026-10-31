# Tích hợp API Đánh giá Flutter — 18/10/2026

Đã nối Flutter theo source Backend d115541. Chưa cập nhật runtime/schema 5001; chưa kiểm thử đầu-cuối trên điện thoại với API mới. Không gọi POST/upload/kiểm duyệt thật trong tác vụ này.

## Phần đã nối

- Route `/review/:contractDetailId` dùng ID trên URL để GET biểu mẫu; không phụ thuộc extra. Lỗi/403/404/API chưa sẵn sàng hiển thị retry, không hiển thị form trống hoặc fallback mock. Loading và đổi đối tượng xóa dữ liệu cũ; generation guard bỏ response về muộn.
- DioReviewRepository → ReviewRemoteDataSource → ApiClient.instance, giữ interceptor Bearer hiện có. DTO API tiếng Việt riêng, không dùng parser fixture tiếng Anh. Chỉ dùng bốn endpoint đã có: biểu mẫu, tạo review, cua-toi, upload `/api/danh-gia/{id}/anh`; không bịa GET review theo id.
- Biểu mẫu quyết định duocDanhGia/lý do/ID review đã có/giới hạn comment/số ảnh. Chip dùng ma/ten từ catalog; ẩn PHU_KIEN_DAY_DU. Từ preview vẫn có fixture/mock riêng được inject, không đưa mock vào luồng thật.
- POST JSON trả review server thật (ID/tên/ngày/trạng thái); Cubit không dựng kết quả giả. Giữ input khi lỗi, khóa gửi lặp. Timeout/5xx/response không parse được hoặc 409 kích hoạt GET biểu mẫu + cua-toi để đối soát; không tự retry POST. Không mặc định mọi 409 là trùng. Nếu chưa đối soát được, khóa gửi lại cho đến khi đối soát thành công.
- Tạo review trước, upload từng file bằng field `anh`, multipart và MIME theo magic bytes JPEG/PNG/WEBP. Lưu trạng thái riêng pending/uploaded/uncertain cùng server ID/URL. Lỗi một ảnh không tạo lại review. Chỉ retry pending theo thao tác người dùng, sau GET cua-toi và kiểm trạng thái CHO_DUYET; dừng khi đã duyệt/từ chối. Ảnh timeout luôn phải refresh server trước, không tự gán một URL mới cho local path khi API thiếu thông tin nhận diện, không retry mù.
- Sau đối soát POST timeout tìm thấy review, ảnh local chưa từng được gửi được giữ là pending; không tự upload. Người dùng kiểm tra server rồi chủ động gửi phần còn lại. Sau mở lại màn hình chỉ dùng URL server trả, không coi local path là URL đã lưu.
- CHO_DUYET/DA_DUYET/TU_CHOI map riêng; rejected reuse card nội dung chỉ đọc với màu lỗi/note từ server. Unknown/null thành trạng thái chưa xác định, không approved. Không có sửa/gửi lại review bị từ chối. Không hiển thị Chính hãng từ `chinhHang=true` hard-code, không suy badge đã thuê từ fixture.
- CTA Đánh giá chỉ ở hợp đồng HOAN_THANH. Một assigned detail mở trực tiếp; nhiều detail dùng ReviewDevicePicker với AssignedContractDevice/BookedContractDevice sẵn có, mỗi serial mở đúng ID. Backend vẫn kiểm quyền/điều kiện cuối cùng.
- Tap ngoài nhận xét unfocus mà không nuốt tap chip/nút. Nút gửi chừa viewInsets bàn phím, tiêu đề chip wrap nếu thiếu chiều ngang. Giữ dialog thoát khi draft đã sửa và chặn Back/nút quay lại trong lúc POST/upload/đối soát.
- TokenStorage thêm broadcast không chứa token khi save/delete; ReviewCubit xóa account-scoped state ngay khi phiên đổi. Data source kiểm session trước/sau HTTP, không nhận response của phiên cũ. Không sửa nghiệp vụ Auth.

## File và component

Tạo:

- `lib/features/review/data/review_api_dto.dart`
- `lib/features/review/data/review_remote_data_source.dart`
- `lib/features/review/data/repositories/dio_review_repository.dart`
- `lib/features/review/domain/models/review_form.dart`
- `lib/features/review/presentation/widgets/review_device_picker.dart`
- `test/review_api_integration_test.dart`

Cập nhật: ReviewRepository/MockReviewRepository, ReviewCubit/ReviewState, ReviewDetailModel/ReviewSubmissionData, ReviewPage, ReviewCommentCard/ReviewHighlightsCard/ReviewPendingCard, route review, CTA ContractPage và observer phiên trong TokenStorage. Không tạo Cubit trùng, HTTP client production mới hoặc package mới. Reuse AppText/PrimaryButton, các card review, image picker/viewer, Dio, GoRouter, models thiết bị hợp đồng, dialog hiện có.

Backup các file liên quan trước khi sửa: `D:\KhoaLuan\Mobile\review-integration-backup-20261018`. Đối chiếu hash xác nhận các Dart file có sẵn ngoài review/router/CTA/session observer không đổi, giữ các thay đổi local trước tác vụ. HEAD mobile giữ dc7ad35; index vẫn chưa staged. Không sửa BASE_URL, Android, pubspec, Backend, SQL, .env, Cart/Search/Notification/FCM hoặc container; không commit/push/stash.

## Kiểm chứng

```text
flutter test --no-pub test/review_api_integration_test.dart test/review_feature_test.dart
48 PASS, 0 FAIL (32 API/Cubit/widget + 16 preview/regression).

flutter test --no-pub test/review_api_integration_test.dart --plain-name
  "timeout after commit reconciles without repeating POST or uploading local photos"
1 PASS, 0 FAIL sau thay đổi giữ hàng đợi pending; không gửi lại POST/upload tự động.

flutter test --no-pub test/review_api_integration_test.dart test/contract_navigation_back_test.dart test/contract_detail_layout_test.dart
22 ca regression đã PASS trong lượt chạy chung với test API (một finder của test API khi đó
bị trùng Serial giữa hợp đồng và bottom sheet, đã sửa scope finder và test lại đạt).
```

Các test dùng HTTP giả/fixture, VNPAY/Cloudinary/DB/Firebase không được gọi. Ca bộ review từng lỗi compile, focus assertion sai đối tượng và thiếu pump UI đã được chẩn đoán/sửa; giữ assertion, không skip. Ca inset điện thoại phát hiện lỗi thật nút bị che/tiêu đề tràn, đã sửa và xác nhận 48 ca đạt.

`flutter analyze --no-pub` toàn dự án không sạch: cảnh báo/lint có sẵn trong AppTextField, Cart, scanner/identity, signing repository, rental_state và script test cũ. Một lint mới trong test review đã sửa bằng braces; không sửa các cảnh báo ngoài phạm vi. Analyze riêng review, TokenStorage, router, ContractPage và hai file test review đạt No issues found. `git diff --check` toàn repo còn blank line EOF của app.dart đã có trước tác vụ; file đó không bị thay bởi tích hợp này.

## Giới hạn và ca Swagger/điện thoại sau khi runtime mới sẵn sàng

- Backend form không công bố giới hạn byte ảnh. Client dùng số lượng/giới hạn nhận xét từ form và kiểm MIME; server vẫn quyết định dung lượng theo config Cloudinary. Không hard-code một giới hạn byte được coi là chính xác khi cấu hình runtime chưa biết. Backend cần thêm field nếu muốn prevalidate byte động trên client.
- Chưa có upload idempotency key/hash local trong API; không thể xác nhận ảnh timeout tương ứng URL nào nếu có người gửi đồng thời. Giữ uncertain, hiển thị ảnh server và chặn gửi lại ảnh đó. Hàng đợi file local chỉ ở bộ nhớ màn hình; khi rời/đóng app, mở lại tải review/ảnh server, không tự khôi phục hoặc gửi lại ảnh local.
- Các fix concurrency review/ảnh, cleanup DB-failure và quyết định legacy/migration vẫn thuộc Backend. Không thay chính sách review cũ hoặc tự bật Firebase. Tích hợp Flutter không chứng minh DB đã tương thích hoặc runtime đã có endpoint.

Khi Backend được phép nạp runtime/schema/config mới:

1. Swagger GET biểu mẫu bằng customer test sở hữu detail của hợp đồng HOAN_THANH; GET cua-toi đối chiếu trước khi tạo. Kiểm catalog/limit/duocDanhGia và tài khoản không có quyền. Dùng dữ liệu mới riêng, không hai hợp đồng được bảo toàn.
2. Trên điện thoại mở hợp đồng hoàn tất: một thiết bị vào đúng detail; nhiều thiết bị chọn đúng serial. Thử mở lại route không extra và review đã gửi, đổi account, offline/403/404.
3. Chọn sao/chip, nhập nhận xét giới hạn, tap ngoài/chip, bấm gửi khi keyboard đang mở. Xác nhận một POST, ID/ngày/tên từ server, không phụ kiện/fixture ID trong payload. Không tự retry nếu ngắt mạng sau gửi; dùng Đối soát đánh giá.
4. Dùng detail khác cho Swagger POST hoặc thử trùng, tránh tạo cùng review từ Swagger rồi hiểu nhầm thao tác app. Phân biệt 409 trùng với chưa hoàn tất và trường hợp server 500 do unique race hiện chưa được fix.
5. Upload ảnh một phần/giới hạn/MIME/số lượng bằng dữ liệu test được phép; đối chiếu cua-toi.hinhAnh. Thử timeout: refresh server, không tự gửi lại ảnh chưa xác định. Mở lại app chỉ hiển thị URL server.
6. Khi được phép kiểm duyệt, Staff Swagger PUT kiem-duyet sang DA_DUYET/TU_CHOI rồi mở lại màn. Kiểm note/từ chối/unknown không thành approved, không có sửa/gửi lại mà Backend chưa hỗ trợ.

Chưa thực hiện các ca ghi/ảnh/kiểm duyệt thật nêu trên; đây là checklist cho lượt kiểm thử đầu-cuối được phép sau triển khai.
