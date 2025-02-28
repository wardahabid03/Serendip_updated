import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:serendip/models/places.dart';
import '../../../core/utils/image_markers.dart';
import '../widgets/get_directions.dart';
import 'map_layer.dart';
import 'package:flutter/material.dart';


class PlacesLayer implements MapLayer {
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Map<String, Polyline> _polylines = {}; // Store polylines with unique IDs
  List<Place> _places = [];
  Place? _selectedPlace;
  LatLng? _userLocation;

  void updatePlaces(List<Place> places) {
    _places = places;
    _updateMarkers();
  }

  void setUserLocation(LatLng location) {
    _userLocation = location;
    if (_selectedPlace != null) {
      _updateRoute();
    }
  }

  void selectPlace(Place place) {
    _selectedPlace = place;
    _updateMarkers();
    if (_userLocation != null) {
      _updateRoute();
    }
  }

  void _updateMarkers() async {
    _markers.clear();
    
    if (_selectedPlace != null) {
      BitmapDescriptor icon = await CustomMarkerHelper.getCustomMarker(_selectedPlace!.imageUrl);

      _markers.add(
        Marker(
          markerId: MarkerId('selected_place_${_selectedPlace!.name}'),
          position: LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude),
          infoWindow: InfoWindow(
            title: _selectedPlace!.name,
            snippet: '${_selectedPlace!.category1} • ${_selectedPlace!.category2} • ${_selectedPlace!.category3}',
          ),
          icon: icon,
        ),
      );
    }
  }

  /// ✅ **Updated `_updateRoute()` using DirectionsService**
  Future<void> _updateRoute() async {
    if (_selectedPlace == null || _userLocation == null) return;

    try {
      // Fetch optimized route with simplification
      List<LatLng> routePoints = await DirectionsService.getDirections(
        _userLocation!,
        LatLng(_selectedPlace!.latitude, _selectedPlace!.longitude),
      );

      _addRoutePolyline(routePoints);
    } catch (e) {
      print("Error fetching directions: $e");
    }
  }

  /// ✅ **Simplified `_addRoutePolyline()`**
  void _addRoutePolyline(List<LatLng> routePoints) {
    _polylines.clear(); // Clear previous routes

    _polylines["route"] = Polyline(
      polylineId: PolylineId("route"),
      points: routePoints,
      color: Colors.blue, // Highlighted route
      width: 6,
      patterns: const [], // No pattern for simplicity
    );
  }

  @override
  Set<Marker> getMarkers() => _markers;

  @override
  Set<Circle> getCircles() => _circles;

  @override
  Set<Polyline> getPolylines() => _polylines.values.toSet();

  @override
  void clear() {
    _markers.clear();
    _circles.clear();
    _polylines.clear();
    _places.clear();
    _selectedPlace = null;
  }

  @override
  void update() {
    _updateMarkers();
    if (_selectedPlace != null && _userLocation != null) {
      _updateRoute();
    }
  }

  @override
  void onTap(LatLng position) {
    if (_places.isEmpty) return;

    Place? closestPlace;
    double minDistance = double.infinity;

    for (var place in _places) {
      final placePosition = LatLng(place.latitude, place.longitude);
      final distance = _calculateDistance(position, placePosition);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPlace = place;
      }
    }

    if (closestPlace != null && minDistance < 1.0) {
      selectPlace(closestPlace);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
}
