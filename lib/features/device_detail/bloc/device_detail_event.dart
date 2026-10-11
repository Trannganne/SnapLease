abstract class DeviceDetailEvent {}

class LoadDeviceDetail extends DeviceDetailEvent {
  final String deviceId;

  LoadDeviceDetail(this.deviceId);
}
