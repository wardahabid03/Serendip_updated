
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/core/constant/colors.dart';
import '../../../core/utils/marker_utils.dart';
import 'map_layer.dart';

class TripsLayer extends MapLayer {
  final Map<String, Polyline> _tripPolylines = {};
  final Map<String, Marker> _tripMarkers = {};
  final Map<String, Circle> _tripCircles = {};
  Timer? _circleAnimationTimer; // Store timer instance

  @override
  Set<Marker> getMarkers() => _tripMarkers.values.toSet();

  @override
  Set<Polyline> getPolylines() => _tripPolylines.values.toSet();

  @override
  Set<Circle> getCircles() => _tripCircles.values.toSet();

  Future<void> addTripPolyline(List<LatLng> path, String tripId) async {
    if (path.isEmpty) return;

    final startIcon = await getCustomIcon("assets/images/pin2.png");
    final endIcon = await getCustomIcon("assets/images/pin.png");

    _tripPolylines[tripId] = Polyline(
      polylineId: PolylineId(tripId),
      points: path,
      color: Colors.red,
      width: 6,
    );

    _tripMarkers["start_$tripId"] = Marker(
      markerId: MarkerId("start_$tripId"),
      position: path.first,
      infoWindow: InfoWindow(title: "Trip Start"),
      icon: startIcon,
    );

    _tripMarkers["end_$tripId"] = Marker(
      markerId: MarkerId("end_$tripId"),
      position: path.last,
      infoWindow: InfoWindow(title: "Trip End"),
      icon: endIcon,
    );

    notifyListeners();
  }

  Future<void> updateTripPolyline(List<LatLng> path, String tripId) async {
  if (path.isEmpty) return;

      final startIcon = await getCustomIcon("assets/images/pin2.png");

  _tripPolylines[tripId] = Polyline(
    polylineId: PolylineId(tripId),
    points: path,
    color: Colors.blue,
    width: 6,
  );

   _tripMarkers["start_$tripId"] = Marker(
      markerId: MarkerId("start_$tripId"),
      position: path.first,
      infoWindow: InfoWindow(title: "Trip Start"),
      icon: startIcon,
    );


  notifyListeners();
}


  void addRecordingTripEffect(LatLng position) {
    String circleId = "recording_trip_circle";

    _tripCircles[circleId] = Circle(
      circleId: CircleId(circleId),
      center: position,
      radius: 100,
      fillColor: tealColor.withOpacity(0.5),
      strokeColor: Colors.red,
      strokeWidth: 2,
    );

    // Stop previous animation if it exists
    _circleAnimationTimer?.cancel();

    // Start the animation
    animateCircleExpansion(circleId);
    notifyListeners();
  }

  void animateCircleExpansion(String circleId) {
    double radius = 100;
    _circleAnimationTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      radius = (radius == 100) ? 80 : 100;
      if (_tripCircles.containsKey(circleId)) {
        _tripCircles[circleId] = _tripCircles[circleId]!.copyWith(radiusParam: radius);
        notifyListeners();
      } else {
        timer.cancel(); // Stop animation if circle is removed
      }
    });
  }

  void stopRecordingTripEffect() {
    _circleAnimationTimer?.cancel();
    _tripCircles.clear(); // Remove circle when trip stops
    notifyListeners();
  }

  @override
  void clear() {
    _tripPolylines.clear();
    _tripMarkers.clear();
    _tripCircles.clear();
    _circleAnimationTimer?.cancel(); // Stop animation when clearing
    notifyListeners();
  }

  @override
  void onTap(LatLng position) {}
}


