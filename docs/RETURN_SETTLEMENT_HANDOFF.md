# Hoàn trả và quyết toán — Mobile ứng viên

Màn riêng `/contract/:id/settlement`, mở từ thẻ Hoàn trả & quyết toán ở Chi tiết hợp đồng. Reuse ContractDetailCubit, ContractRepository, PaymentRepository, ContractSectionCard, timeline, loaders/theme và ReviewDevicePicker. Không thêm package/Bloc. Backend mới/migration13 phải sẵn sàng trước kiểm thử điện thoại; code Flutter không chứng minh runtime đã triển khai.

Chi tiết: [API và bốn bảng](../../backend/Docs/API_RETURN_SETTLEMENT.md). Source tiền/status/hash/quyền thao tác là Backend. DU_KIEN/null không phải quyết toán cuối hoặc0đ. Staff ghi DA_HOAN chưa có nghĩa khách đã nhận. Có hoàn: khách xác nhận đúng giao dịch/số tiền/hash trong dialog; không hoàn: Đồng ý quyết toán riêng, cả sau thu thêm đủ. Phản hồi mở chặn hoàn tất; Staff trả lời vẫn chờ khách chấp nhận/rút. Chỉ HOAN_THANH và eligible CT từ Backend mới mở luồng đánh giá.

Màn gồm kết quả, thực nhận/kiểm tra từng serial, nghĩa vụ/căn cứ, thu tiền ngoài cọc và cọc riêng, khấu trừ, theo dõi thu/hoàn, phản hồi và nút cuối theo capability. Dữ liệu ảnh mẫu không thành số tiền/tài khoản/hotline/deadline thực. Chưa có endpoint chứng từ quyết toán xuất file nên không dựng download/share giả. Ảnh nhận trả tải qua repository, chỉ API origin nhận auth.

Pull-to-refresh, quay lại route, resume và sự kiện push đều GET. Không giả trạng thái thành công hoặc phụ thuộc duy nhất push. Khi timeout chỉ GET đối soát operation và tài chính; không tự POST lại. Local chỉ giữ operation key/phase để tránh lặp sau đóng app; không lưu tiền/quyết toán làm nguồn nghiệp vụ. GET operation=false vẫn chặn, cần đối soát thêm; không hiểu là được gửi lại.

VNPAY thêm thu tổng THU_QUYET_TOAN nhưng mặc định `Vnpay__SettlementEnabled=false` cho đến khi HTTPS callback/IPN đúng API5001 và đăng ký Sandbox được xác nhận. Giữ PAY-02, reuse luồng link/status/return; redirect thành công không tự đánh đã thu. Không hoàn VNPAY tự động.

## Checklist sau khi gói Backend được duyệt và readiness đạt

1. Người dùng tự cập nhật/run source Flutter, giữ BASE_URL `http://127.0.0.1:5001`, thiết bị R5GL66JBAEA qua USB `adb -s R5GL66JBAEA reverse tcp:5001 tcp:5001`. Agent chưa build/cài APK hoặc đổi reverse trong lượt code.
2. Đúng kimngan, mở hợp đồng được chỉ định rồi refresh. Trước nhận trả phải chưa ghi nhận nhận đủ/hoàn tiền. Không nhận trả hai hợp đồng hiện tại chỉ để xem UI; cần bước nghiệp vụ được xác nhận riêng sau triển khai.
3. Sau Staff nhận đủ atomic: mở thẻ/màn quyết toán; đối chiếu serial, thực nhận, thời gian kiểm tra khác nhau; thiết bị chưa kiểm tra có nhãn phù hợp. Khách không có nút Staff nhận trả/chốt tiền.
4. Sau kiểm tra/chốt: đối chiếu tiền thuê, phụ lục có hiệu lực, trễ và bồi thường có căn cứ; thuê/phí đã thu khác cọc, không trừ hai lần. Còn thiếu/ngoại lệ phải hiện blocker. Kiểm tra layout320px/text lớn/lý do dài trên điện thoại thực.
5. Có hoàn: trước Staff ghi hoàn chưa có nút xác nhận đã nhận. Sau ghi hoàn, kiểm đúng phương thức/số tiền, khách tự bấm xác nhận khi thực tế nhận khoản mô phỏng đã thống nhất. Không có refund0. Nhánh0/thu đủ phải khách đồng ý quyết toán.
6. Gửi phản hồi, Staff trả lời, khách kiểm kết quả rồi chấp nhận hoặc rút; chưa xử lý không được hoàn tất. Chuyển nền/quay lại/refresh vẫn đúng dữ liệu. Nếu timeout dừng, không bấm lại.
7. Chỉ sau Backend HOAN_THANH: kiểm tra thông báo hệ thống hiện có và mở đúng hợp đồng/quyết toán; eligible CT mở picker/đánh giá hiện có. Không tạo review/fixture giả để đạt trạng thái.

Đã có widget/parser/Cubit/repository regression và SQL/API bằng dữ liệu tổng hợp cô lập. Chưa coi đây là PASS điện thoại, Web, email/FCM/gateway thật hoặc nhận trả/quyết toán hai hợp đồng hiện tại. Không thay runtime/config, migration DB test, OTP/FCM, merchant/tunnel hoặc tiền thật trong lượt code.
