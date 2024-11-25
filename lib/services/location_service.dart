import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<LatLng> getUserLocation() async {
    // Check if permission is granted
    PermissionStatus permission = await Permission.locationWhenInUse.request();
    if (permission.isGranted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } else {
      // Handle permission denial
      throw PermissionDeniedException('Location permission is denied.');
    }
  }
}
