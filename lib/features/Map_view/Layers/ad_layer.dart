import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:serendip/models/ads_model.dart';

import '../../../core/utils/image_markers.dart';
import 'map_layer.dart';

class AdLayer extends MapLayer {
  final Set<Marker> _adMarkers = {};
  final Set<Polyline> _routePolyline = {};
  LatLng? _userLocation;

  final String _apiKey = "AIzaSyC4gULFHsrb14nNcNzQNwZa6tG0HNBIwmg";

  void setUserLocation(LatLng location) {
    _userLocation = location;
    notifyListeners();
  }

  Future<void> setAds(List<BusinessAd> ads) async {
    _adMarkers.clear();

    for (var ad in ads) {
      final LatLng adLatLng = LatLng(ad.location.latitude, ad.location.longitude);
      final icon = await CustomMarkerHelper.getCustomMarker(ad.imageUrl);

      _adMarkers.add(
        Marker(
          markerId: MarkerId('ad_${ad.id}'),
          position: adLatLng,
          icon: icon,
          infoWindow: InfoWindow(
            title: ad.title,
            snippet: ad.description,
            onTap: () {
              // Optional: handle CTA on tap
              print('CTA: ${ad.cta}');
            },
          ),
          onTap: () {
            _drawRouteToAd(adLatLng);
          },
        ),
      );
    }

    notifyListeners();
  }

  Future<void> _drawRouteToAd(LatLng adLocation) async {
    if (_userLocation == null) return;

    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${_userLocation!.latitude},${_userLocation!.longitude}"
        "&destination=${adLocation.latitude},${adLocation.longitude}"
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

    _routePolyline.clear();
    _routePolyline.add(
      Polyline(
        polylineId: const PolylineId("ad_route"),
        points: routePoints,
        color: Colors.green,
        width: 5,
      ),
    );
    notifyListeners();
  }

  @override
  Set<Marker> getMarkers() => _adMarkers;

  @override
  Set<Circle> getCircles() => {};

  @override
  Set<Polyline> getPolylines() => _routePolyline;

  @override
  void clear() {
    _adMarkers.clear();
    _routePolyline.clear();
    _userLocation = null;
    notifyListeners();
  }

  @override
  void onTap(LatLng position) {
    // No-op for this layer
  }
}
