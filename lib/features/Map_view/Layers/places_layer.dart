import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:serendip/models/places.dart';
import '../../../core/utils/image_markers.dart';
import 'map_layer.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class PlacesLayer extends MapLayer {
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};
  List<Place> _places = [];
  Place? _selectedPlace;
  LatLng? _userLocation;
  final String _apiKey = "AIzaSyC4gULFHsrb14nNcNzQNwZa6tG0HNBIwmg";

  void updatePlaces(List<Place> places) {
    _places = places;
    _updateMarkers();
    notifyListeners();
  }

  void setUserLocation(LatLng location) {
    _userLocation = location;
    if (_selectedPlace != null) {
      _updateRoute();
    }
    notifyListeners();
  }

  void selectPlace(Place place) {
    _selectedPlace = place;
    _updateMarkers();
    if (_userLocation != null) {
      _updateRoute();
    }
    notifyListeners();
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


  Future<void> _updateRoute() async {
    if (_selectedPlace == null || _userLocation == null) return;
    
    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${_userLocation!.latitude},${_userLocation!.longitude}"
        "&destination=${_selectedPlace!.latitude},${_selectedPlace!.longitude}"
        "&key=$_apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          _addRoutePolyline(encodedPolyline);
        }
      } else {
        print("Failed to fetch directions: ${response.body}");
      }
    } catch (e) {
      print("Error fetching directions: $e");
    }
  }

  void _addRoutePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
    List<LatLng> routePoints = decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId("route"),
        points: routePoints,
        color: Colors.blue,
        width: 5,
      ),
    );
    notifyListeners();
  }

  @override
  Set<Marker> getMarkers() => _markers;

  @override
  Set<Circle> getCircles() => _circles;

  @override
  Set<Polyline> getPolylines() => _polylines;

  @override
  void clear() {
    _markers.clear();
    _circles.clear();
    _polylines.clear();
    _places.clear();
    _selectedPlace = null;
    notifyListeners();
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
    const double earthRadius = 6371;
    
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