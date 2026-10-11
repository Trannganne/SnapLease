import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/device_detail_repository.dart';
import 'device_detail_event.dart';
import 'device_detail_state.dart';

class DeviceDetailBloc extends Bloc<DeviceDetailEvent, DeviceDetailState> {
  final DeviceDetailRepository repository;

  DeviceDetailBloc({required this.repository})
    : super(const DeviceDetailState()) {
    on<LoadDeviceDetail>(_onLoadDeviceDetail);
  }

  Future<void> _onLoadDeviceDetail(
    LoadDeviceDetail event,
    Emitter<DeviceDetailState> emit,
  ) async {
    emit(state.copyWith(status: DeviceDetailStatus.loading));
    try {
      final detail = await repository.getDeviceDetail(event.deviceId);
      emit(state.copyWith(status: DeviceDetailStatus.loaded, detail: detail));
    } catch (e) {
      emit(
        state.copyWith(
          status: DeviceDetailStatus.error,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
