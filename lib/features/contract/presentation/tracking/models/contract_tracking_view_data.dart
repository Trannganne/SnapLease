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
    final format = DateFormat('HH:mm • dd/MM/yyyy');
    if (contract.status == 'DA_HUY') {
      return _cancelled(contract, format);
    }
    final devices = contract.assignedDevices;
    final completeAssignment =
        contract.bookedDevices.isNotEmpty &&
        contract.bookedDevices
            .map((b) => b.modelId)
            .toSet()
            .every(
              (id) =>
                  devices.where((d) => d.modelId == id).length ==
                  contract.bookedDevices
                      .where((b) => b.modelId == id)
                      .fold<int>(0, (sum, b) => sum + b.quantity),
            ) &&
        devices.every(
          (d) => contract.bookedDevices.any((b) => b.modelId == d.modelId),
        );
    final delivered =
        completeAssignment &&
        devices.isNotEmpty &&
        devices.every((d) => d.handedOverAt != null);
    final returned =
        completeAssignment &&
        devices.isNotEmpty &&
        devices.every((d) => d.returnedAt != null);
    String? latest(Iterable<DateTime?> values) {
      final dates = values.whereType<DateTime>().toList()..sort();
      return dates.isEmpty ? null : format.format(dates.last);
    }

    final step = switch (status) {
      ContractTrackingStatus.awaitingSignature => 1,
      ContractTrackingStatus.signed ||
      ContractTrackingStatus.awaitingHandover => 2,
      ContractTrackingStatus.renting => 3,
      ContractTrackingStatus.awaitingReturn => 4,
      ContractTrackingStatus.completed => 5,
      _ => -1,
    };
    TimelineStepState progress(int index) =>
        step == index
            ? TimelineStepState.active
            : step > index
            ? TimelineStepState.completed
            : TimelineStepState.pending;
    return ContractTrackingViewData(
      status: status,
      currentStatusTitle: 'TRẠNG THÁI HIỆN TẠI: ${status.label.toUpperCase()}',
      currentStatusDescription: switch (status) {
        ContractTrackingStatus.awaitingHandover =>
          'Thiết bị đã được chuẩn bị. Nhân viên sẽ xác nhận bàn giao thực tế tại cửa hàng.',
        ContractTrackingStatus.renting => 'Hợp đồng đang thuê.',
        ContractTrackingStatus.awaitingReturn =>
          'Hợp đồng đang ở bước hoàn trả/quyết toán.',
        ContractTrackingStatus.completed => 'Hợp đồng đã hoàn tất.',
        ContractTrackingStatus.cancelled => 'Hợp đồng đã hủy.',
        ContractTrackingStatus.awaitingSignature => 'Hợp đồng đang chờ ký.',
        ContractTrackingStatus.signed =>
          'Hợp đồng đã ký, chưa hoàn tất chuẩn bị thiết bị.',
        ContractTrackingStatus.unknown =>
          'Chưa có thông tin trạng thái hợp đồng.',
      },
      highlightText: 'Hạn trả: ${format.format(contract.effectiveReturnDate)}',
      showPickupSection: false,
      showPaymentSection: false,
      showLegalSection: false,
      showNoticeSection: false,
      bottomCtaLabel:
          status == ContractTrackingStatus.renting
              ? 'Yêu cầu gia hạn thuê'
              : '',
      timelineSteps: [
        ContractTimelineStep(
          title: 'Đã tạo hợp đồng',
          subtitle: 'Thông tin hợp đồng',
          timestamp: format.format(contract.date),
          state: TimelineStepState.completed,
        ),
        ContractTimelineStep(
          title: 'Ký hợp đồng',
          subtitle: switch (contract.signingMethod) {
            'DIEN_TU' => 'Ký điện tử',
            'BAN_GIAY' => 'Ký bản giấy',
            'MAN_HINH' => 'Ký trên màn hình',
            _ => 'Chưa có thông tin hình thức ký',
          },
          timestamp:
              contract.signedAt == null
                  ? null
                  : format.format(contract.signedAt!),
          state:
              contract.signedAt == null
                  ? progress(1)
                  : TimelineStepState.completed,
        ),
        ContractTimelineStep(
          title: 'Bàn giao thiết bị',
          subtitle:
              delivered
                  ? 'Đã có ngày giao thực tế cho tất cả thiết bị'
                  : 'Chưa có đủ ngày giao thực tế',
          timestamp:
              delivered ? latest(devices.map((d) => d.handedOverAt)) : null,
          state:
              delivered
                  ? TimelineStepState.completed
                  : step == 2
                  ? TimelineStepState.active
                  : TimelineStepState.pending,
        ),
        ContractTimelineStep(
          title: 'Đang thuê',
          subtitle: 'Theo trạng thái hợp đồng',
          state: progress(3),
        ),
        ContractTimelineStep(
          title: 'Hoàn trả/quyết toán',
          subtitle:
              returned
                  ? 'Đã ghi nhận ngày nhận lại thiết bị'
                  : 'Theo trạng thái hợp đồng',
          timestamp: returned ? latest(devices.map((d) => d.returnedAt)) : null,
          state:
              returned
                  ? TimelineStepState.completed
                  : TimelineStepState.pending,
        ),
        ContractTimelineStep(
          title: 'Hoàn tất hợp đồng',
          subtitle:
              contract.status == 'HOAN_THANH'
                  ? 'Backend đã xác nhận hoàn thành hợp đồng'
                  : 'Chưa hoàn thành',
          state:
              contract.status == 'HOAN_THANH'
                  ? TimelineStepState.completed
                  : TimelineStepState.pending,
        ),
      ],
    );
  }

  static ContractTrackingViewData _cancelled(
    ContractModel contract,
    DateFormat format,
  ) {
    final cancellation = contract.cancellation;
    final details = <String>[
      if (cancellation?.processingReason != null)
        'Lý do hủy: ${cancellation!.processingReason}',
      if (cancellation?.requestReason != null)
        'Lý do yêu cầu hủy: ${cancellation!.requestReason}',
      if (cancellation?.requestedAtUtc != null)
        'Gửi yêu cầu: ${format.format(cancellation!.requestedAtUtc!.add(const Duration(hours: 7)))} (giờ Việt Nam)',
    ];
    final handedOver =
        contract.assignedDevices.where((d) => d.handedOverAt != null).toList();
    final returned =
        contract.assignedDevices.where((d) => d.returnedAt != null).toList();
    String latest(Iterable<DateTime> dates) =>
        format.format((dates.toList()..sort()).last);
    return ContractTrackingViewData(
      status: ContractTrackingStatus.cancelled,
      currentStatusTitle: 'TRẠNG THÁI HIỆN TẠI: ĐÃ HỦY',
      currentStatusDescription: 'Hợp đồng đã hủy.',
      highlightText: '',
      showPickupSection: false,
      showPaymentSection: false,
      showLegalSection: false,
      showNoticeSection: false,
      bottomCtaLabel: '',
      timelineSteps: [
        ContractTimelineStep(
          title: 'Đã tạo hợp đồng',
          subtitle: 'Thông tin hợp đồng',
          timestamp: format.format(contract.date),
          state: TimelineStepState.completed,
        ),
        if (contract.signedAt != null)
          ContractTimelineStep(
            title: 'Ký hợp đồng',
            subtitle: switch (contract.signingMethod) {
              'DIEN_TU' => 'Ký điện tử',
              'BAN_GIAY' => 'Ký bản giấy',
              'MAN_HINH' => 'Ký trên màn hình',
              _ => '',
            },
            timestamp: format.format(contract.signedAt!),
            state: TimelineStepState.completed,
          ),
        if (handedOver.isNotEmpty)
          ContractTimelineStep(
            title: 'Đã ghi nhận bàn giao',
            subtitle: 'Đã bàn giao ${handedOver.length} thiết bị',
            timestamp: latest(handedOver.map((d) => d.handedOverAt!)),
            state: TimelineStepState.completed,
          ),
        if (returned.isNotEmpty)
          ContractTimelineStep(
            title: 'Đã nhận lại thiết bị',
            subtitle: 'Đã nhận lại ${returned.length} thiết bị',
            timestamp: latest(returned.map((d) => d.returnedAt!)),
            state: TimelineStepState.completed,
          ),
        ContractTimelineStep(
          title: 'Hợp đồng đã hủy',
          subtitle: details.join('\n'),
          timestamp:
              cancellation?.effectiveAtUtc == null
                  ? null
                  : 'Thời gian hủy: ${format.format(cancellation!.effectiveAtUtc!.add(const Duration(hours: 7)))} (giờ Việt Nam)',
          state: TimelineStepState.cancelled,
        ),
      ],
    );
  }
}
