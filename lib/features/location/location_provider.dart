import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../../core/utils/navigator_key.dart';
import '../../services/location_service.dart';
import '../Trip_Tracking/provider/trip_provider.dart';
import 'dart:math';


class LocationProvider with ChangeNotifier {
  LatLng? _currentLocation;
  LatLng? _lastRecordedLocation;
  final LocationService _locationService = LocationService();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("user_locations");
  StreamSubscription? _locationSubscription;

  LatLng? get currentLocation => _currentLocation;

  LocationProvider() {
    _init();
  }

  void _init() async {
    await _fetchCurrentLocation();
    _listenForLiveLocations();
    _locationService.startBackgroundTracking();
    _startAutoTripTracking();  // Start listening for trip updates
  }

  Future<void> _fetchCurrentLocation() async {
    LatLng? location = await _locationService.getUserLocation();
    if (location != null) {
      _currentLocation = location;
      notifyListeners();
      await _locationService.updateUserLocation(location);
    }
  }

  void _listenForLiveLocations() {
    _dbRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<String, dynamic> data = Map<String, dynamic>.from(event.snapshot.value as Map);
        notifyListeners();
      }
    });
  }

  /// **Starts automatic trip tracking**
  void _startAutoTripTracking() {
    _locationSubscription = Stream.periodic(Duration(seconds: 5)).listen((_) async {
      LatLng? newLocation = await _locationService.getUserLocation();
      if (newLocation != null && _shouldRecordLocation(newLocation)) {
        _updateTripLocation(newLocation);
      }
    });
  }

  /// **Check if the new location is far enough from the last recorded location**
  bool _shouldRecordLocation(LatLng newLocation) {
    if (_lastRecordedLocation == null) return true;

    const double minDistance = 10.0; // Minimum meters before recording again
    double distance = _calculateDistance(
      _lastRecordedLocation!.latitude,
      _lastRecordedLocation!.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    return distance > minDistance;
  }

  /// **Update the trip provider with new location**
  void _updateTripLocation(LatLng newLocation) {
    _currentLocation = newLocation;
    _lastRecordedLocation = newLocation;
    notifyListeners();

    final tripProvider = Provider.of<TripProvider>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );

    if (tripProvider.isRecording) {
      tripProvider.addLocation(newLocation);
    }
  }

  /// **Calculates distance between two LatLng points (Haversine Formula)**
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Radius of Earth in meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180.0);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}
