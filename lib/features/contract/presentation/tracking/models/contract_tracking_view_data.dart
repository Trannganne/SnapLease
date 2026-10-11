import 'package:intl/intl.dart';
import '../../../services/contract_pdf_service.dart';
import 'contract_tracking_status.dart';
import 'contract_timeline_step.dart';

class ContractTrackingViewData {
  final ContractTrackingStatus status;
  final String currentStatusTitle;
  final String currentStatusDescription;
  final String highlightText;
  final List<ContractTimelineStep> timelineSteps;
  final bool showPickupSection;
  final bool showPaymentSection;
  final bool showLegalSection;
  final bool showNoticeSection;
  final String bottomCtaLabel;

  ContractTrackingViewData({
    required this.status,
    required this.currentStatusTitle,
    required this.currentStatusDescription,
    required this.highlightText,
    required this.timelineSteps,
    required this.showPickupSection,
    required this.showPaymentSection,
    required this.showLegalSection,
    required this.showNoticeSection,
    required this.bottomCtaLabel,
  });

  static ContractTrackingViewData fromContract(
    ContractModel contract,
    ContractTrackingStatus status,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    final pickupDateStr = dateFormat.format(contract.pickupDate);
    final pickupTimeStr = timeFormat.format(contract.pickupDate);
    final returnDateStr = dateFormat.format(contract.returnDate);
    final returnTimeStr = timeFormat.format(contract.returnDate);

    switch (status) {
      case ContractTrackingStatus.awaitingHandover:
        return ContractTrackingViewData(
          status: status,
          currentStatusTitle: "TRẠNG THÁI HIỆN TẠI: CHỜ BÀN GIAO",
          currentStatusDescription:
              "Hợp đồng điện tử đã ký thành công. Kỹ thuật viên đang hoàn thiện kiểm tra cảm biến và vệ sinh lens. Quý khách vui lòng đến chi nhánh đúng giờ hẹn.",
          highlightText: "Lịch hẹn: $pickupTimeStr • $pickupDateStr tại ${contract.branchName}",
          showPickupSection: true,
          showPaymentSection: true,
          showLegalSection: true,
          showNoticeSection: true,
          bottomCtaLabel: "Xem hợp đồng điện tử",
          timelineSteps: [
            ContractTimelineStep(
              title: 'Đã tạo hợp đồng',
              subtitle: 'Chi tiết hợp đồng đã được tạo',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đã ký điện tử & OTP',
              subtitle: 'Hợp đồng được ký xác nhận',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ bàn giao máy',
              subtitle: 'Thiết bị đang được chuẩn bị',
              state: TimelineStepState.active,
            ),
            ContractTimelineStep(
              title: 'Đang trong thời gian thuê',
              subtitle: 'Sử dụng thiết bị',
              state: TimelineStepState.pending,
            ),
            ContractTimelineStep(
              title: 'Chờ hoàn trả thiết bị',
              subtitle: 'Đến hạn trả máy',
              state: TimelineStepState.pending,
            ),
            ContractTimelineStep(
              title: 'Hoàn tất hợp đồng',
              subtitle: 'Nghiệm thu và hoàn cọc',
              state: TimelineStepState.pending,
            ),
          ],
        );
      case ContractTrackingStatus.renting:
        final now = DateTime.now();
        final diff = contract.returnDate.difference(now);
        String remainingText = '';
        if (diff.isNegative) {
          remainingText = "(Quá hạn)";
        } else if (diff.inDays > 0) {
          remainingText = "(Còn ${diff.inDays} ngày ${diff.inHours % 24} giờ)";
        } else {
          remainingText = "(Còn ${diff.inHours} giờ ${diff.inMinutes % 60} phút)";
        }

        return ContractTrackingViewData(
          status: status,
          currentStatusTitle: "TRẠNG THÁI HIỆN TẠI: ĐANG TRONG THỜI GIAN THUÊ",
          currentStatusDescription:
              "Thiết bị đã được bàn giao đầy đủ phụ kiện. Gói RentSafe Basic kích hoạt toàn diện. Thời gian thuê kết thúc vào $returnTimeStr ngày $returnDateStr.",
          highlightText:
              "Thời hạn hoàn trả: $returnTimeStr • $returnDateStr $remainingText",
          showPickupSection: false,
          showPaymentSection: false,
          showLegalSection: false,
          showNoticeSection: false,
          bottomCtaLabel: "Yêu cầu gia hạn thuê",
          timelineSteps: [
            ContractTimelineStep(
              title: 'Đã tạo hợp đồng',
              subtitle: 'Chi tiết hợp đồng đã được tạo',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đã ký điện tử & OTP',
              subtitle: 'Hợp đồng được ký xác nhận',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ bàn giao máy',
              subtitle: 'Thiết bị đã được bàn giao',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đang trong thời gian thuê',
              subtitle: 'Sử dụng thiết bị',
              state: TimelineStepState.active,
            ),
            ContractTimelineStep(
              title: 'Chờ hoàn trả thiết bị',
              subtitle: 'Đến hạn trả máy',
              state: TimelineStepState.pending,
            ),
            ContractTimelineStep(
              title: 'Hoàn tất hợp đồng',
              subtitle: 'Nghiệm thu và hoàn cọc',
              state: TimelineStepState.pending,
            ),
          ],
        );
      case ContractTrackingStatus.awaitingReturn:
        return ContractTrackingViewData(
          status: status,
          currentStatusTitle: "TRẠNG THÁI HIỆN TẠI: SẮP ĐẾN HẠN HOÀN TRẢ",
          currentStatusDescription:
              "Hôm nay là hạn trả máy. Quý khách vui lòng kiểm tra đầy đủ pin, sạc, nắp cáp lens trước khi mang tới ${contract.branchName}.",
          highlightText: "Hạn cuối hôm nay: $returnTimeStr • ${contract.branchName}",
          showPickupSection: false,
          showPaymentSection: false,
          showLegalSection: false,
          showNoticeSection: false,
          bottomCtaLabel: "Chỉ đường trả thiết bị",
          timelineSteps: [
            ContractTimelineStep(
              title: 'Đã tạo hợp đồng',
              subtitle: 'Chi tiết hợp đồng đã được tạo',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đã ký điện tử & OTP',
              subtitle: 'Hợp đồng được ký xác nhận',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ bàn giao máy',
              subtitle: 'Thiết bị đã được bàn giao',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đang trong thời gian thuê',
              subtitle: 'Đã hết thời gian sử dụng',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ hoàn trả thiết bị',
              subtitle: 'Mang thiết bị đến chi nhánh',
              state: TimelineStepState.active,
            ),
            ContractTimelineStep(
              title: 'Hoàn tất hợp đồng',
              subtitle: 'Nghiệm thu và hoàn cọc',
              state: TimelineStepState.pending,
            ),
          ],
        );
      case ContractTrackingStatus.completed:
        final depositStr = currencyFormat.format(contract.deposit);
        return ContractTrackingViewData(
          status: status,
          currentStatusTitle: "TRẠNG THÁI HIỆN TẠI: HỢP ĐỒNG ĐÃ TẤT TOÁN",
          currentStatusDescription:
              "Kỹ thuật viên đã nghiệm thu thiết bị đạt chuẩn. Tiền cọc $depositStr đã được hoàn trả thành công qua tài khoản ngân hàng của quý khách.",
          highlightText: "Đã hoàn cọc $depositStr",
          showPickupSection: false,
          showPaymentSection: false,
          showLegalSection: false,
          showNoticeSection: false,
          bottomCtaLabel: "Đánh giá",
          timelineSteps: [
            ContractTimelineStep(
              title: 'Đã tạo hợp đồng',
              subtitle: 'Chi tiết hợp đồng đã được tạo',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đã ký điện tử & OTP',
              subtitle: 'Hợp đồng được ký xác nhận',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ bàn giao máy',
              subtitle: 'Thiết bị đã được bàn giao',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Đang trong thời gian thuê',
              subtitle: 'Đã hết thời gian sử dụng',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Chờ hoàn trả thiết bị',
              subtitle: 'Đã hoàn trả thiết bị',
              state: TimelineStepState.completed,
            ),
            ContractTimelineStep(
              title: 'Hoàn tất hợp đồng',
              subtitle: 'Hoàn cọc thành công',
              state: TimelineStepState.completed,
            ), // Or active-final
          ],
        );
    }
  }
}
