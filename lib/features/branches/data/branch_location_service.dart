import 'package:geolocator/geolocator.dart';
import '../../../domain/entities/geo_coordinates.dart';

abstract interface class BranchLocationService {
  Future<GeoCoordinates> current();
}

class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
}

class DeviceBranchLocationService implements BranchLocationService {
  @override
  Future<GeoCoordinates> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Vị trí đang tắt. Bạn vẫn có thể xem các chi nhánh.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Quyền vị trí bị chặn. Bạn có thể bật trong cài đặt hoặc tiếp tục xem chi nhánh.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationFailure(
        'Chưa được cấp quyền vị trí. Bạn vẫn xem được chi nhánh.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    final coordinates = GeoCoordinates(position.latitude, position.longitude);
    if (!coordinates.isValid) {
      throw const LocationFailure('Chưa lấy được vị trí hợp lệ.');
    }
    return coordinates;
  }
}
