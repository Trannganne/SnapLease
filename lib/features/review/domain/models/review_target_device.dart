class ReviewTargetDevice {
  final String contractId;
  final String detailId;
  final String deviceId;
  final String modelId;
  final String modelName;
  final String? categoryName;
  final String? brandName;
  final String branchName;
  final String? serialNumber;
  final String? deviceImageUrl;
  final String contractStatus;

  const ReviewTargetDevice({
    required this.contractId,
    required this.detailId,
    required this.deviceId,
    required this.modelId,
    required this.modelName,
    this.categoryName,
    this.brandName,
    required this.branchName,
    this.serialNumber,
    this.deviceImageUrl,
    required this.contractStatus,
  });

  bool get isCompleted => contractStatus == 'HOAN_THANH';

  Map<String, dynamic> toJson() => {
    'contractId': contractId,
    'detailId': detailId,
    'deviceId': deviceId,
    'modelId': modelId,
    'modelName': modelName,
    'categoryName': categoryName,
    'brandName': brandName,
    'branchName': branchName,
    'serialNumber': serialNumber,
    'deviceImageUrl': deviceImageUrl,
    'contractStatus': contractStatus,
  };

  factory ReviewTargetDevice.fromJson(Map<String, dynamic> json) =>
      ReviewTargetDevice(
        contractId: json['contractId'] as String? ?? '',
        detailId: json['detailId'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        modelId: json['modelId'] as String? ?? '',
        modelName: json['modelName'] as String? ?? '',
        categoryName: json['categoryName'] as String?,
        brandName: json['brandName'] as String?,
        branchName: json['branchName'] as String? ?? '',
        serialNumber: json['serialNumber'] as String?,
        deviceImageUrl: json['deviceImageUrl'] as String?,
        contractStatus: json['contractStatus'] as String? ?? '',
      );
}
