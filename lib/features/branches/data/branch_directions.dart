import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/geo_coordinates.dart';

class BranchDirections {
  final Future<bool> Function(Uri) launch;
  BranchDirections({Future<bool> Function(Uri)? launch})
    : launch = launch ?? _external;
  static Future<bool> _external(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  Uri destination(GeoCoordinates coordinates) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${coordinates.latitude},${coordinates.longitude}',
      });
  Future<bool> open(GeoCoordinates coordinates) async {
    if (!coordinates.isValid) return false;
    try {
      return await launch(destination(coordinates));
    } catch (_) {
      return false;
    }
  }
}
