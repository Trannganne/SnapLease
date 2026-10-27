# API Backend33 — thay đổi cần Web/Mobile rà soát

Danh sách lấy từ source trial hiện tại, chưa phải bằng chứng endpoint đã smoke thành công. Prefix là `/api`. Bearer token đổi purpose sang `schema33-v2` và gắn `PhienBanBaoMat`: client phải đăng nhập lại; đổi/reset mật khẩu làm token cũ mất hiệu lực.

| Nhóm | Route/hành vi cần cập nhật |
|---|---|
| Email | Mới: POST `/auth/email/xac-minh/gui`, POST `/auth/email/xac-minh` (`token`), PUT `/auth/email` (`email`). Email xác minh unique. |
| Reset | POST `/auth/quen-mat-khau` vẫn dùng tên field `emailHoacSoDienThoai`, nhưng chỉ email đã xác minh được xử lý; trả202 chung. POST `/auth/dat-lai-mat-khau` nhận `resetToken`, `matKhauMoi`; token dùng một lần theo epoch/hash. Trial fake sender, không gửi thư thật. |
| Reset: response/giới hạn | Đặt lại thành công trả204; token hoặc mật khẩu không hợp lệ trả400; nhóm auth giới hạn5 yêu cầu/phút/IP và trả429 khi vượt. Mật khẩu theo `PasswordPolicy` hiện có (8–128 ký tự, có hoa/thường/số/ký tự đặc biệt). Không trả reset token trong response. Các chi tiết này đối chiếu trực tiếp AuthEndpoints/Program/PasswordPolicy, không thay API. |
| Lịch | GET `/cua-hang/{id}/lich-lam-viec` trả lịch cố định hằng ngày từ config08–20 giờ VN; không còn hai bảng lịch. Availability tiếp tục theo khoảng và capacity, không suy từ trạng thái serial. |
| Giỏ/hold/contract | Giữ ID/version lựa chọn gốc riêng với snapshot giỏ hợp đồng. TTL hold20 phút; chỉnh khoảng thực sự mới reset TTL. Contract đọc `TrangThaiNhanTra`; không suy nhận trả từ row audit bị loại. |
| Hủy | GET/POST `/hop-dong/{id}/huy-truoc-ban-giao`; POST `/hop-dong/{id}/huy-truc-tiep` cho Admin ngoại lệ có căn cứ/lý do; POST `/hop-dong/{id}/doi-soat-huy`. Hủy xử lý trực tiếp, hợp đồng giữ `DA_HUY`. |
| No-show | GET `/hop-dong/can-kiem-tra-nhan`, GET `/hop-dong/{id}/xac-minh-khong-den`, POST `/hop-dong/{id}/xac-nhan-khong-den`. Gửi `operationId`, `phienBanXacMinhDaXem` cùng chứng cứ hiện hành; từ hẹn+2h, Staff đúng chi nhánh. Đủ điều kiện thì hủy trong cùng guard/transaction, không job tự hủy theo giờ. |
| Bỏ hàng chờ hủy | GET `/yeu-cau-huy/cho-duyet` và PUT `/yeu-cau-huy/{id}/xu-ly` trả410; POST `/yeu-cau-huy/{id}/de-nghi-ngoai-le` trả410, chuyển thao tác Admin trực tiếp. |
| Nhận trả | POST `/hop-dong/{id}/nhan-lai`: nhận đủ một lần, kết quả từng serial. Chỉnh giờ chung tại PUT `/hop-dong/{id}/nhan-lai/thoi-gian` trước final, giữ metadata lần sửa gần nhất trên biên bản. PUT `/chi-tiet-hop-dong/{id}/thoi-gian-nhan` trả409 `USE_ATOMIC_RECEIPT_CORRECTION`. Nhiều ảnh vẫn là quan hệ `AnhBienBan`. |
| Quyết toán | Chỉ final trên `QuyetToanHopDong`; GET `/hop-dong/{id}/quyet-toan`, POST `.../quyet-toan/chot`, `.../quyet-toan/thu-them`, `.../hoan-coc`. Dùng `operationId`/hash đã đọc cho các thao tác tài chính. Hai field ACK nhánh không hoàn nằm trên finalQ và không tham gia hash tiền bất biến. |
| Không có hoàn | Mới POST `/hop-dong/{id}/quyet-toan/xac-nhan-hoan-tat` cho Customer chủ hợp đồng, sau nhận trả/final/thu đủ. Adapter POST `.../quyet-toan/phan-hoi` chỉ giữ `DONG_Y_QUYET_TOAN` và `DA_NHAN_HOAN`; không còn feedback workflow. PUT `.../quyet-toan/phan-hoi/{feedbackId}/xu-ly` trả410. |
| Khoản hoàn | GET `/hop-dong/{id}/khoan-hoan`; PUT `/thanh-toan/{id}/xac-nhan-hoan` (alias `xac-nhan-hoan-huy`) cho Staff đúng chi nhánh/Admin, chỉ xác nhận đã hoàn ngoài thực tế, không bắt ảnh/mã/retype tiền. POST `/thanh-toan/{id}/xac-nhan-nhan-hoan` cho Customer chủ hợp đồng từng khoản: `operationId`, `soTienXacNhan`, `maBamKhoanHoan` từ GET. |
| Thu thừa | POST `/hop-dong/{id}/hoan-thu-thua` nhận `operationId`, `phuongThuc` (`CHUYEN_KHOAN` mặc định); ngoài hủy không cần tạo Q/đối soát hủy giả. |
| Gia hạn | Từng lần trên `PhuLuc` cùng chữ ký/PDF; giữ quy tắc source hiện hành (không auto, không20 phút ký). Không có bảng history bổ sung. |
| Đánh giá/media | Đánh giá sau hoàn thành; không history kiểm duyệt riêng. Trial ảnh giả tại `/trial-media/{name}` với guard quyền sở hữu/visibility; không phải URL Cloudinary dùng chung. |

DTO đầy đủ (các trường chứng cứ no-show, biên bản, version/hash) nằm ở source endpoint và Swagger. Client phải dùng lỗi409/410 để tải lại trạng thái hoặc chuyển thao tác phù hợp; không tự đổi trạng thái thành thành công và không tự retry POST sau timeout. Không bật gateway/IPN/QueryDR, OTP/email/FCM hoặc provider thật khi kiểm trial.
