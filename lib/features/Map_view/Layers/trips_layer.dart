import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_layer.dart'; // Importing base layer class

class TripsLayer extends MapLayer {
  final Map<String, Polyline> _tripPolylines = {}; // Stores trip polylines
  final Map<String, Marker> _tripMarkers = {}; // Stores start/end markers

  @override
  Set<Marker> getMarkers() {
    return _tripMarkers.values.toSet();
  }

  @override
  Set<Polyline> getPolylines() {
    return _tripPolylines.values.toSet();
  }

  @override
  Set<Circle> getCircles() {
    return {}; // No circles needed for trips
  }

  void addTripPolyline(List<LatLng> path, String tripId) {
    if (path.isEmpty) return;

    // Adding a polyline for the trip
    _tripPolylines[tripId] = Polyline(
      polylineId: PolylineId(tripId),
      points: path,
      color: Colors.blue,
      width: 5,
    );

    // Adding markers for start & end points
    _tripMarkers["start_$tripId"] = Marker(
      markerId: MarkerId("start_$tripId"),
      position: path.first,
      infoWindow: InfoWindow(title: "Trip Start"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    _tripMarkers["end_$tripId"] = Marker(
      markerId: MarkerId("end_$tripId"),
      position: path.last,
      infoWindow: InfoWindow(title: "Trip End"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }

  @override
  void clear() {
    _tripPolylines.clear();
    _tripMarkers.clear();
  }

  @override
  void onTap(LatLng position) {
    // Handle tap event on trips (optional)
  }
}
