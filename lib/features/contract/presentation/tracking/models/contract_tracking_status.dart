enum ContractTrackingStatus {
  awaitingHandover,
  renting,
  awaitingReturn,
  completed,
}

extension ContractTrackingStatusExt on ContractTrackingStatus {
  String get label {
    switch (this) {
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
