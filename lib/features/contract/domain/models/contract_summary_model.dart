enum ContractStatus {
  all,
  active,
  pending,
  completed,
  cancelled,
}

class ContractSummaryModel {
  final String id;
  final ContractStatus status;
  final String imagePath;
  final String deviceName;
  final String packageInfo;
  final DateTime pickupDate;
  final DateTime returnDate;
  final String branchName;
  final String? statusAlertMessage;
  final int totalAmount;
  final String? originalStatus;

  const ContractSummaryModel({
    required this.id,
    required this.status,
    required this.imagePath,
    required this.deviceName,
    required this.packageInfo,
    required this.pickupDate,
    required this.returnDate,
    required this.branchName,
    this.statusAlertMessage,
    required this.totalAmount,
    this.originalStatus,
  });
}
