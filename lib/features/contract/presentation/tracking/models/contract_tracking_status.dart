enum ContractTrackingStatus {
  awaitingSignature,
  signed,
  cancelled,
  unknown,
  awaitingHandover,
  renting,
  awaitingReturn,
  completed,
}

extension ContractTrackingStatusExt on ContractTrackingStatus {
  String get label {
    switch (this) {
      case ContractTrackingStatus.awaitingSignature:
        return 'Chờ ký';
      case ContractTrackingStatus.signed:
        return 'Đã ký';
      case ContractTrackingStatus.cancelled:
        return 'Đã hủy';
      case ContractTrackingStatus.unknown:
        return 'Chưa có trạng thái';
      case ContractTrackingStatus.awaitingHandover:
        return 'Chờ bàn giao';
      case ContractTrackingStatus.renting:
        return 'Đang thuê';
      case ContractTrackingStatus.awaitingReturn:
        return 'Chờ hoàn trả';
      case ContractTrackingStatus.completed:
        return 'Hoàn tất';
    }
  }
}
