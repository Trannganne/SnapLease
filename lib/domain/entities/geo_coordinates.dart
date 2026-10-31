import 'dart:math' as math;

class GeoCoordinates {
  final double latitude;
  final double longitude;
  const GeoCoordinates(this.latitude, this.longitude);

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static GeoCoordinates? parse(Object? latitude, Object? longitude) {
    if (latitude is! num || longitude is! num) return null;
    final value = GeoCoordinates(latitude.toDouble(), longitude.toDouble());
    return value.isValid ? value : null;
  }

  double distanceKmTo(GeoCoordinates other) {
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(other.latitude - latitude);
    final dLon = radians(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(latitude)) *
            math.cos(radians(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371.0088 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
