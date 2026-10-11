import '../../../../domain/entities/device_detail.dart';

enum DeviceDetailStatus { initial, loading, loaded, error }

class DeviceDetailState {
  final DeviceDetailStatus status;
  final DeviceDetail? detail;
  final String? errorMessage;

  const DeviceDetailState({
    this.status = DeviceDetailStatus.initial,
    this.detail,
    this.errorMessage,
  });

  DeviceDetailState copyWith({
    DeviceDetailStatus? status,
    DeviceDetail? detail,
    String? errorMessage,
  }) {
    return DeviceDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
