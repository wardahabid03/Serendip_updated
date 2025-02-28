import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("user_locations");
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Request location permission
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  // Get user location
  Future<LatLng?> getUserLocation() async {
    bool permissionGranted = await requestLocationPermission();
    if (!permissionGranted) return null;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  // Update user location in Firebase
  Future<void> updateUserLocation(LatLng location) async {
    String? uid = currentUserId;
    if (uid != null) {
      await _dbRef.child(uid).set({
        "latitude": location.latitude,
        "longitude": location.longitude,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // Start background tracking using Geolocator
void startBackgroundTracking() async {
  bool permissionGranted = await requestLocationPermission();
  if (!permissionGranted) {
    print("Location permission not granted.");
    return;
  }

  print('started backgroung location tracking');

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // Update every 10 meters

    ),
  ).listen((Position position) {
    LatLng newLocation = LatLng(position.latitude, position.longitude);
    print("New location received: $newLocation");
    updateUserLocation(newLocation);
  }, onError: (error) {
    print("Error in location stream: $error");
  });
}

}
